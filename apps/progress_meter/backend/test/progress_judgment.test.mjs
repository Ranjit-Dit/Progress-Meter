import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import {
  createProgressJudgment,
  validateProgressJudgmentRequest,
} from "../progress_judgment.mjs";
import { createCoachServer, loadConfig } from "../server.mjs";

const NOW = Date.parse("2026-10-30T12:00:00Z");
const KEY = "synthetic-progress-key-not-a-real-secret";
const config = () => loadConfig({ OPENAI_API_KEY: KEY });
const assessment = (
  id = "a",
  completedAt = "2026-10-30T10:00:00Z",
  extras = {},
) => ({
  id,
  topic: "Binary search",
  level: "beginner",
  questionCount: 4,
  completedAt,
  totalScore: 70,
  understandingScore: 80,
  applicationScore: 60,
  feedback: "Justify the invariant.",
  missingConcepts: ["Termination argument"],
  ...extras,
});
const request = (extras = {}) => ({
  requestId: "review-1",
  track: "academic",
  evidenceKey: "evidence-1",
  assessments: [assessment()],
  ...extras,
});
const many = () => [
  assessment("a", "2026-10-30T10:00:00Z"),
  assessment("b", "2026-10-29T10:00:00Z"),
  assessment("c", "2026-10-28T10:00:00Z"),
];
const judgments = (ids = ["a"], extras = {}) => ({
  summary:
    "Understanding is stronger than application. Explain each step and retest.",
  metrics: ["knowledge", "practice", "consistency", "impact"].map((metric) => ({
    metric,
    score: 65,
    feedback: "Demonstrate all required reasoning.",
    evidenceIds: ids,
  })),
  ...extras,
});
const response = (value, extras = {}) =>
  new Response(
    JSON.stringify({
      status: "completed",
      output: [
        {
          type: "message",
          content: [{ type: "output_text", text: JSON.stringify(value) }],
        },
      ],
      ...extras,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
const code = (expected) => (error) => error.code === expected;
const service = (fetchImpl, extra = {}) =>
  createProgressJudgment({
    config: config(),
    fetchImpl,
    now: () => NOW,
    ...extra,
  });

test("progress review whitelists assessed summaries and excludes future evidence before judging", () => {
  const parsed = validateProgressJudgmentRequest(
    request({
      manualScores: { knowledge: 100 },
      name: "Private name",
      tasks: ["Private task"],
      assessments: [
        assessment("future", "2026-10-31T10:00:00Z"),
        {
          ...assessment(),
          answers: "Private written answer",
          sessionToken: "private-token",
        },
      ],
    }),
    { now: () => NOW },
  );
  assert.equal(parsed.assessments.length, 1);
  assert.equal(parsed.assessments[0].id, "a");
  assert.equal(JSON.stringify(parsed).includes("Private"), false);
  assert.equal(parsed.manualScores, undefined);
  for (const extra of [
    { assessments: [] },
    { assessments: [assessment("future", "2026-11-01T10:00:00Z")] },
  ]) {
    assert.throws(
      () => validateProgressJudgmentRequest(request(extra), { now: () => NOW }),
      code("insufficient_evidence"),
    );
  }
  for (const extra of [
    { assessments: [assessment("a"), assessment("a")] },
    {
      assessments: [
        assessment("a", "2026-10-30T10:00:00Z", { totalScore: 100 }),
      ],
    },
    { assessments: [assessment("a", "2026-02-31T10:00:00Z")] },
    {
      assessments: [
        assessment("a", "2026-10-30T10:00:00Z", { questionCount: 21 }),
      ],
    },
    {
      assessments: Array.from({ length: 13 }, (_, index) =>
        assessment(`a${index}`),
      ),
    },
    { requestId: "bad/path" },
    { evidenceKey: "x".repeat(129) },
    { track: "unknown" },
  ])
    assert.throws(
      () => validateProgressJudgmentRequest(request(extra), { now: () => NOW }),
      code("invalid_request"),
    );
});

test("progress review uses strict live output, server-only credentials, and no fabricated missing metrics", async () => {
  let calls = 0;
  const lab = service(async (url, options) => {
    calls++;
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(options.headers.Authorization, `Bearer ${KEY}`);
    const payload = JSON.parse(options.body);
    assert.equal(payload.store, false);
    assert.equal(payload.text.format.strict, true);
    assert.equal(payload.text.format.schema.properties.metrics.minItems, 4);
    assert.equal(payload.text.format.schema.additionalProperties, false);
    assert.equal(payload.tools, undefined);
    assert.match(payload.instructions, /untrusted data/);
    const input = JSON.parse(payload.input[0].content);
    assert.deepEqual(input.eligibility, { consistency: false, impact: false });
    assert.equal(input.evidenceKey, undefined);
    assert.equal(input.requestId, undefined);
    return response(judgments());
  });
  const result = await lab.review(request());
  assert.equal(result.track, "academic");
  assert.equal(result.source, "openai");
  assert.equal(result.evidenceKey, "evidence-1");
  assert.equal(result.model, config().model);
  assert.deepEqual(
    result.metrics.map((item) => item.score),
    [65, 65, null, null],
  );
  assert.match(result.metrics[2].feedback, /three distinct days/);
  assert.match(result.metrics[3].feedback, /two comparable tests/);
  assert.equal(JSON.stringify(result).includes(KEY), false);
  await lab.review(request());
  assert.equal(calls, 1);
});

test("progress review accepts AI judgments only with enough cited comparable and recent evidence", async () => {
  const result = await service(async () =>
    response(judgments(["a", "b", "c"])),
  ).review(request({ assessments: many() }));
  assert.deepEqual(
    result.metrics.map((item) => item.score),
    [65, 65, 65, 65],
  );
  const missingCitations = judgments(["a", "b"]);
  await assert.rejects(
    service(async () => response(missingCitations)).review(
      request({ assessments: many() }),
    ),
    code("invalid_response"),
  );
  const mixed = many().map((item, index) => ({
    ...item,
    topic: `Different topic ${index}`,
  }));
  const outcomes = await service(async () =>
    response(judgments(["a", "b", "c"])),
  ).review(request({ assessments: mixed }));
  assert.equal(
    outcomes.metrics.find((item) => item.metric === "impact").score,
    null,
  );
  const old = many().map((item) => ({
    ...item,
    completedAt: item.completedAt.replace("10-", "09-"),
  }));
  const stale = await service(async () =>
    response(judgments(["a", "b", "c"])),
  ).review(request({ assessments: old }));
  assert.equal(
    stale.metrics.find((item) => item.metric === "consistency").score,
    null,
  );
});

test("progress review rejects invented evidence IDs, duplicate metrics and out-of-range judgments", async () => {
  const invented = judgments(["made-up"]);
  const duplicate = judgments();
  duplicate.metrics[1].metric = "knowledge";
  const invalidScore = judgments();
  invalidScore.metrics[0].score = 101;
  const noEvidence = judgments();
  noEvidence.metrics[0].evidenceIds = [];
  for (const value of [
    invented,
    duplicate,
    invalidScore,
    noEvidence,
    { ...judgments(), metrics: judgments().metrics.slice(1) },
  ]) {
    await assert.rejects(
      service(async () => response(value)).review(request()),
      code("invalid_response"),
    );
  }
  const unknown = judgments();
  unknown.metrics[0] = {
    metric: "knowledge",
    score: null,
    feedback: "Too little topic coverage to judge.",
    evidenceIds: [],
  };
  assert.equal(
    (await service(async () => response(unknown)).review(request())).metrics[0]
      .score,
    null,
  );
});

test("progress review retry IDs coalesce, conflict on changed evidence, and recover after failures", async () => {
  let calls = 0;
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const lab = service(async () => {
    calls++;
    await gate;
    return response(judgments());
  });
  const a = lab.review(request());
  const b = lab.review(request());
  release();
  assert.deepEqual(await a, await b);
  assert.equal(calls, 1);
  await assert.rejects(
    lab.review(request({ evidenceKey: "different" })),
    code("idempotency_conflict"),
  );
  let failure = true;
  const retry = service(async () =>
    failure
      ? new Response("private upstream secret", { status: 500 })
      : response(judgments()),
  );
  await assert.rejects(retry.review(request()), code("upstream_unavailable"));
  failure = false;
  assert.equal((await retry.review(request())).source, "openai");
});

test("progress review honors live mode, cache expiry and sanitized upstream failures", async () => {
  await assert.rejects(
    service(
      async () => {
        throw new Error("must not run");
      },
      { config: { ...config(), mode: "demo" } },
    ).review(request()),
    code("review_requires_live"),
  );
  await assert.rejects(
    service(
      async () => {
        throw new Error("must not run");
      },
      { config: { ...config(), apiKey: "" } },
    ).review(request()),
    code("not_configured"),
  );
  for (const [status, expected] of [
    [401, "upstream_auth"],
    [403, "upstream_auth"],
    [429, "upstream_rate_limited"],
    [500, "upstream_unavailable"],
  ]) {
    await assert.rejects(
      service(
        async () => new Response("private-credential", { status }),
      ).review(request()),
      (error) =>
        error.code === expected &&
        !error.message.includes("private-credential"),
    );
  }
  await assert.rejects(
    service(async () => response({}, { status: "incomplete" })).review(
      request(),
    ),
    code("incomplete_response"),
  );
  await assert.rejects(
    service(async () =>
      response(
        {},
        { output: [{ type: "message", content: [{ type: "refusal" }] }] },
      ),
    ).review(request()),
    code("refused"),
  );
  await assert.rejects(
    service(async () => new Response("x".repeat(256 * 1024 + 1))).review(
      request(),
    ),
    code("invalid_response"),
  );
  let current = NOW;
  let calls = 0;
  const lab = service(
    async () => {
      calls++;
      return response(judgments());
    },
    { now: () => current },
  );
  await lab.review(request());
  current += 31 * 60 * 1000;
  await lab.review(request());
  assert.equal(calls, 2);
});

test("progress review HTTP shares authentication and rejects insufficient evidence before AI calls", async (t) => {
  let calls = 0;
  const server = createCoachServer({
    config: { ...config(), token: "private-gateway-token-of-required-length" },
    now: () => NOW,
    fetchImpl: async () => {
      calls++;
      return response(judgments());
    },
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(
    () =>
      new Promise((resolve) => {
        server.closeAllConnections();
        server.close(resolve);
      }),
  );
  const url = `http://127.0.0.1:${server.address().port}/api/progress/review`;
  const post = (body, authorized = true) =>
    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(authorized
          ? { Authorization: "Bearer private-gateway-token-of-required-length" }
          : {}),
      },
      body: JSON.stringify(body),
    });
  assert.equal((await post(request(), false)).status, 401);
  assert.equal((await post(request({ assessments: [] }))).status, 400);
  assert.equal(calls, 0);
  const valid = await post(request());
  assert.equal(valid.status, 200);
  assert.equal((await valid.json()).metrics.length, 4);
  assert.equal(calls, 1);
  const health = await fetch(url.replace("/api/progress/review", "/health"));
  assert.deepEqual(await health.json(), {
    status: "ok",
    configured: true,
    mode: "live",
  });
});
