import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createCoachServer, loadConfig, validateRequest } from '../server.mjs';

const KEY = 'test-only-never-a-real-openai-key';
const VALUES = { knowledge: 60, practice: 55, consistency: 75, impact: 50 };
function snapshot() {
  return {
    question: 'What should I focus on this week?',
    context: {
      track: 'academic',
      metricLabels: { knowledge: 'Understanding', practice: 'Practice', consistency: 'Consistency', impact: 'Outcomes' },
      rubric: 'Scores are equal-weight self-assessments from 0 to 100.',
      history: [{ date: '2026-10-29T00:00:00.000Z', score: 60, metrics: { ...VALUES } }],
      goals: [{ title: 'Practice regularly', metric: 'practice', target: 70, deadline: '2026-11-05T00:00:00.000Z' }],
      benchmark: { score: 80, metrics: { knowledge: 80, practice: 80, consistency: 80, impact: 80 }, isExample: true },
      isSampleData: true,
    },
    conversation: [],
  };
}
function success(reply = 'Focus on a small, repeatable practice session.') {
  return new Response(JSON.stringify({ status: 'completed', output: [{ type: 'reasoning', summary: [] }, { type: 'message', content: [{ type: 'output_text', text: JSON.stringify({ reply, suggestions: [{ title: 'Practice on three days', metric: 'practice', target: 65, days: 7 }] }) }] }] }), { status: 200, headers: { 'Content-Type': 'application/json' } });
}
async function serverFor(t, overrides = {}, fetchImpl = async () => success()) {
  const config = { ...loadConfig({ OPENAI_API_KEY: KEY }), ...overrides };
  const server = createCoachServer({ config, fetchImpl });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  return {
    config, server, base,
    async post(body = snapshot(), headers = {}) {
      const response = await fetch(`${base}/api/coach`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: typeof body === 'string' ? body : JSON.stringify(body) });
      return { response, body: await response.json() };
    },
  };
}

test('configuration defaults to loopback live mode and refuses public unauthenticated binding', () => {
  const config = loadConfig({});
  assert.equal(config.host, '127.0.0.1');
  assert.equal(config.port, 8787);
  assert.equal(config.mode, 'live');
  assert.equal(config.apiKey, '');
  assert.throws(() => loadConfig({ HOST: '0.0.0.0' }), /requires a COACH_ACCESS_TOKEN/);
  assert.equal(loadConfig({ HOST: '0.0.0.0', COACH_ACCESS_TOKEN: 'x'.repeat(24) }).host, '0.0.0.0');
  assert.throws(() => loadConfig({ COACH_MODE: 'fallback' }), /live or demo/);
  assert.throws(() => loadConfig({ COACH_ALLOWED_ORIGIN: 'http://example.com' }), /HTTPS/);
});

test('validates all metrics, whitelists context, and recomputes provided scores', () => {
  const request = snapshot();
  request.context.history[0].score = 99;
  request.context.history[0].privateName = 'Do not forward';
  request.context.secret = 'Do not forward';
  const result = validateRequest(request);
  assert.equal(result.context.history[0].score, 60);
  assert.equal(result.context.secret, undefined);
  assert.equal(result.context.history[0].privateName, undefined);
  assert.throws(() => validateRequest({ ...request, question: '' }), /1–2000/);
  request.context.history[0].metrics.knowledge = 101;
  assert.throws(() => validateRequest(request), /between 0 and 100/);
});

test('health has configuration state without revealing credentials', async (t) => {
  const { base } = await serverFor(t);
  const response = await fetch(`${base}/health`);
  const body = await response.text();
  assert.deepEqual(JSON.parse(body), { status: 'ok', configured: true, mode: 'live' });
  assert.equal(body.includes(KEY), false);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('live mode without a key returns actionable 503 and never silently demos', async (t) => {
  let called = false;
  const { post, base } = await serverFor(t, { apiKey: '' }, async () => { called = true; return success(); });
  assert.equal((await (await fetch(`${base}/health`)).json()).configured, false);
  const result = await post();
  assert.equal(result.response.status, 503);
  assert.equal(result.body.error.code, 'not_configured');
  assert.equal(called, false);
  assert.equal(result.body.source, undefined);
});

test('live request uses Responses structured output with server-only secret and store false', async (t) => {
  const request = snapshot();
  request.conversation = [{ role: 'user', text: 'Can you help me plan?' }, { role: 'assistant', text: 'Let us choose one small goal.' }];
  let calls = 0;
  const { post } = await serverFor(t, {}, async (url, options) => {
    calls++;
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(options.headers.Authorization, `Bearer ${KEY}`);
    assert.ok(options.signal instanceof AbortSignal);
    const payload = JSON.parse(options.body);
    assert.equal(payload.store, false);
    assert.equal(payload.model, 'gpt-6-luna');
    assert.equal(payload.text.format.type, 'json_schema');
    assert.equal(payload.text.format.strict, true);
    assert.equal(payload.text.format.schema.additionalProperties, false);
    assert.equal(payload.input.at(-1).content, request.question);
    assert.equal(payload.input[2].role, 'assistant');
    assert.match(payload.instructions, /self-reported/);
    return success();
  });
  const result = await post(request);
  assert.equal(result.response.status, 200);
  assert.equal(result.body.source, 'openai');
  assert.equal(result.body.model, 'gpt-6-luna');
  assert.equal(result.body.suggestions[0].metric, 'practice');
  assert.equal(JSON.stringify(result.body).includes(KEY), false);
  assert.equal(calls, 1);
});

test('explicit demo mode labels local examples and makes no upstream requests', async (t) => {
  const { post } = await serverFor(t, { mode: 'demo', apiKey: '' }, async () => { throw new Error('must not be called'); });
  const result = await post();
  assert.equal(result.response.status, 200);
  assert.equal(result.body.source, 'demo');
  assert.equal(result.body.model, null);
  assert.match(result.body.reply, /not an OpenAI response/);
  assert.match(result.body.reply, /sample data/);
  assert.equal(result.body.suggestions.length, 1);
  const empty = snapshot();
  empty.context.history = [];
  assert.match((await post(empty)).body.reply, /Start with a check-in/);
});

test('malformed, oversized, invalid and unsupported requests never reach upstream', async (t) => {
  let calls = 0;
  const { post, base } = await serverFor(t, {}, async () => { calls++; return success(); });
  const malformed = await post('{');
  assert.equal(malformed.response.status, 400);
  assert.equal(malformed.body.error.code, 'invalid_json');
  const invalid = snapshot();
  delete invalid.context.history[0].metrics.practice;
  assert.equal((await post(invalid)).response.status, 400);
  assert.equal((await post(' '.repeat(65537))).response.status, 413);
  const tooMany = snapshot();
  tooMany.conversation = Array.from({ length: 9 }, () => ({ role: 'user', text: 'hello' }));
  assert.equal((await post(tooMany)).response.status, 400);
  const wrongType = await fetch(`${base}/api/coach`, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: '{}' });
  assert.equal(wrongType.status, 415);
  assert.equal(calls, 0);
});

test('authorization and unknown browser origins fail before consuming the request quota', async (t) => {
  const token = 'test-gateway-token-not-an-openai-key';
  const { post } = await serverFor(t, { token, rateLimit: 1 });
  assert.equal((await post()).response.status, 401);
  assert.equal((await post(snapshot(), { Authorization: 'Bearer wrong' })).response.status, 401);
  assert.equal((await post(snapshot(), { Authorization: `Bearer ${token}`, Origin: 'https://untrusted.example' })).response.status, 403);
  const result = await post(snapshot(), { Authorization: `Bearer ${token}` });
  assert.equal(result.response.status, 200);
});

test('permits only the explicit browser origin and handles its preflight', async (t) => {
  const origin = 'https://coach.example';
  const { base, post } = await serverFor(t, { allowedOrigin: origin });
  const preflight = await fetch(`${base}/api/coach`, { method: 'OPTIONS', headers: { Origin: origin } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), origin);
  const result = await post(snapshot(), { Origin: origin });
  assert.equal(result.response.headers.get('access-control-allow-origin'), origin);
  assert.equal(result.response.headers.get('access-control-allow-origin') === '*', false);
});

test('local rate limit returns Retry-After without sending another API request', async (t) => {
  let calls = 0;
  const { post } = await serverFor(t, { rateLimit: 1 }, async () => { calls++; return success(); });
  assert.equal((await post()).response.status, 200);
  const limited = await post();
  assert.equal(limited.response.status, 429);
  assert.equal(limited.body.error.code, 'rate_limited');
  assert.ok(Number(limited.response.headers.get('retry-after')) > 0);
  assert.equal(calls, 1);
});

test('concurrency is bounded and capacity is restored after completion', async (t) => {
  let release;
  let entered;
  const started = new Promise((resolve) => { entered = resolve; });
  const waiting = new Promise((resolve) => { release = resolve; });
  const { post } = await serverFor(t, { maxConcurrent: 1 }, async () => { entered(); await waiting; return success(); });
  const first = post();
  await started;
  const busy = await post();
  assert.equal(busy.response.status, 503);
  assert.equal(busy.body.error.code, 'busy');
  release();
  assert.equal((await first).response.status, 200);
  assert.equal((await post()).response.status, 200);
});

test('upstream authentication, rate limit and server errors are sanitized', async (t) => {
  for (const [status, expectedStatus, code] of [[401, 502, 'upstream_auth'], [429, 429, 'upstream_rate_limited'], [500, 502, 'upstream_unavailable']]) {
    const { post } = await serverFor(t, {}, async () => new Response(JSON.stringify({ error: { message: `private ${KEY}` } }), { status }));
    const result = await post();
    assert.equal(result.response.status, expectedStatus);
    assert.equal(result.body.error.code, code);
    assert.equal(JSON.stringify(result.body).includes(KEY), false);
  }
});

test('refusals, incomplete responses, invalid JSON, and out-of-range model suggestions are handled', async (t) => {
  const cases = [
    [{ status: 'completed', output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'private reason' }] }] }, 422, 'refused'],
    [{ status: 'incomplete', output: [] }, 502, 'incomplete_response'],
    [{ status: 'completed', output: [{ type: 'message', content: [{ type: 'output_text', text: 'broken JSON' }] }] }, 502, 'invalid_response'],
    [{ status: 'completed', output: [{ type: 'message', content: [{ type: 'output_text', text: JSON.stringify({ reply: 'Test', suggestions: [{ title: 'Bad goal', metric: 'knowledge', target: 101, days: 7 }] }) }] }] }, 502, 'invalid_response'],
  ];
  for (const [payload, status, code] of cases) {
    const { post } = await serverFor(t, {}, async () => new Response(JSON.stringify(payload), { status: 200 }));
    const result = await post();
    assert.equal(result.response.status, status);
    assert.equal(result.body.error.code, code);
  }
});

test('upstream timeout and transport errors do not leak exceptions or secrets', async (t) => {
  const slow = await serverFor(t, { timeoutMs: 15 }, async (_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new Error(`private ${KEY}`)), { once: true });
  }));
  const timed = await slow.post();
  assert.equal(timed.response.status, 504);
  assert.equal(timed.body.error.code, 'timeout');
  const broken = await serverFor(t, {}, async () => { throw new Error(`private ${KEY}`); });
  const result = await broken.post();
  assert.equal(result.response.status, 502);
  assert.equal(result.body.error.code, 'upstream_unavailable');
  assert.equal(JSON.stringify(result.body).includes(KEY), false);
});
