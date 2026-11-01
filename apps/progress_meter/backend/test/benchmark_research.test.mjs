import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import {
  createBenchmarkResearch,
  validateBenchmarkRequest,
  readiness,
  safePublicUrl,
} from "../benchmark_research.mjs";
import { createCoachServer, loadConfig } from "../server.mjs";
const config = () => loadConfig({ OPENAI_API_KEY: "fake-test-key" });
const req = (extra = {}) =>
  validateBenchmarkRequest("/api/benchmarks/research", {
    requestId: "test-research",
    kind: "person",
    query: "Sample professional",
    context: "Official teaching profile",
    postText: "",
    track: "academic",
    ...extra,
  });
const output = (v) =>
  new Response(
    JSON.stringify({
      status: "completed",
      output: [
        {
          type: "message",
          content: [{ type: "output_text", text: JSON.stringify(v) }],
        },
      ],
    }),
    { headers: { "Content-Type": "application/json" } },
  );
const web = (sources = true) =>
  new Response(
    JSON.stringify({
      status: "completed",
      output: [
        {
          type: "web_search_call",
          action: {
            sources: sources
              ? [{ title: "Official profile", url: "https://example.com/bio" }]
              : [],
          },
        },
        {
          type: "message",
          content: [
            {
              type: "output_text",
              text: "A public biography describes professional teaching.",
              annotations: sources
                ? [
                    {
                      type: "url_citation",
                      url: "https://example.com/bio",
                      title: "Official profile",
                    },
                  ]
                : [],
            },
          ],
        },
      ],
    }),
    { headers: { "Content-Type": "application/json" } },
  );
const plan = (id = "s1", status = "ready") => ({
  status,
  subjectName: "Sample professional",
  headline: "Public teaching evidence",
  summary: "A proposed learning path based on public evidence.",
  warnings: [],
  evidence: [{ text: "The biography describes teaching.", sourceIds: [id] }],
  milestones:
    status === "ready"
      ? Array.from({ length: 5 }, (_, i) => ({
          title: `Step ${i + 1}`,
          description: "Demonstrate this skill with evidence.",
          kind: i === 2 || i === 4 ? "project" : "assessment",
          topic: `Topic ${i + 1}`,
          level: "beginner",
          targetScore: i === 2 || i === 4 ? null : 80,
          sourceIds: [id],
        }))
      : [],
});
const errorCode = (code) => (e) => e.code === code;

test('backend accepts a saved personal-provider roadmap without rewriting provenance', () => {
  const personal = {
    ...plan(), id: 'personal-path', kind: 'person', query: 'A public teacher',
    track: 'academic', researchedAt: '2026-11-01T00:00:00Z', model: 'custom/test-model',
    source: 'ai', sources: [{id: 's1', title: 'Official profile', url: 'https://example.com/bio'}],
    milestones: plan().milestones.map((m, i) => ({...m, id: `m${i + 1}`})),
  };
  const request = validateBenchmarkRequest('/api/benchmarks/review', {
    requestId: 'personal-review', plan: personal, assessments: [], projectEvidence: [],
  });
  assert.equal(request.plan.source, 'ai');
  assert.equal(readiness(request), 0);
});
test("benchmark research uses actual citations and structured inferred milestones", async () => {
  let calls = 0;
  const service = createBenchmarkResearch({
    config: config(),
    fetchImpl: async (url, options) => {
      calls++;
      const p = JSON.parse(options.body);
      assert.equal(p.store, false);
      assert.equal(url, "https://api.openai.com/v1/responses");
      if (calls === 1) {
        assert.equal(p.tools[0].type, "web_search");
        assert.match(p.instructions, /untrusted/);
        return web();
      }
      assert.equal(p.text.format.strict, true);
      return output(plan());
    },
  });
  const a = await service.research(req());
  assert.equal(a.status, "ready");
  assert.equal(a.sources.length, 1);
  assert.equal(a.milestones.length, 5);
  assert.equal(a.milestones[0].id, "m1");
  assert.equal(a.source, "openai");
  assert.equal((await service.research(req())).id, a.id);
  assert.equal(calls, 2);
  await assert.rejects(
    service.research(req({ query: "Another person" })),
    errorCode("idempotency_conflict"),
  );
});
test("benchmark unsafe URLs and invalid fields are rejected before research", () => {
  for (const url of [
    "http://example.com",
    "https://127.0.0.1/a",
    "https://localhost/a",
    "https://u:p@example.com",
    "file:///etc/passwd",
    "https://host.internal/a",
  ]) {
    assert.equal(safePublicUrl(url), null);
    assert.throws(() => req({ query: url }));
  }
  assert.equal(
    safePublicUrl("https://example.com/bio"),
    "https://example.com/bio",
  );
  assert.throws(() => req({ query: "" }));
  assert.throws(() => req({ postText: "x".repeat(10001) }));
});
test("benchmark missing public sources returns no fabricated path", async () => {
  let calls = 0;
  const service = createBenchmarkResearch({
    config: config(),
    fetchImpl: async () => {
      calls++;
      return web(false);
    },
  });
  const result = await service.research(req());
  assert.equal(result.status, "insufficient_sources");
  assert.deepEqual(result.milestones, []);
  assert.equal(calls, 1);
});
test("benchmark ambiguous identities stay unresolved and invented source IDs fail", async () => {
  for (const [value, expected] of [
    [plan("s1", "needs_context"), "needs_context"],
    [plan("invented"), null],
  ]) {
    let calls = 0;
    const service = createBenchmarkResearch({
      config: config(),
      fetchImpl: async () => (++calls === 1 ? web() : output(value)),
    });
    if (expected)
      assert.equal((await service.research(req())).status, expected);
    else
      await assert.rejects(
        service.research(req()),
        errorCode("invalid_response"),
      );
  }
});
test("benchmark pasted post provenance is explicitly unverified", async () => {
  let calls = 0;
  const service = createBenchmarkResearch({
    config: config(),
    fetchImpl: async () => (++calls === 1 ? web(false) : output(plan("s0"))),
  });
  const result = await service.research(
    req({
      kind: "post",
      postText:
        "A role description requires technical teaching and a portfolio.",
    }),
  );
  assert.equal(result.sources[0].url, null);
  assert.ok(result.warnings.some((x) => x.includes("unverified")));
});
test("benchmark review uses authoritative evidence arithmetic and cached replay", async () => {
  let calls = 0;
  const service = createBenchmarkResearch({
    config: config(),
    fetchImpl: async () => {
      calls++;
      return calls === 1
        ? web()
        : calls === 2
          ? output(plan())
          : output({
              summary: "Keep practicing.",
              blockers: ["Missing evidence"],
              nextActions: ["Take the next test"],
              progressPercent: 999,
            });
    },
  });
  const p = await service.research(req());
  const review = validateBenchmarkRequest("/api/benchmarks/review", {
    requestId: "review-1",
    plan: p,
    assessments: [
      {
        milestoneId: "m1",
        score: 40,
        resultId: "lab-one",
        completedAt: new Date().toISOString(),
      },
    ],
    projectEvidence: [
      {
        milestoneId: "m3",
        completed: true,
        notes: "A self-reported deliverable.",
        url: null,
      },
    ],
  });
  assert.equal(readiness(review), 30);
  const a = await service.review(review);
  assert.equal(a.progressPercent, 30);
  assert.deepEqual(await service.review(review), a);
  assert.equal(calls, 3);
});
test("benchmark live-only configuration and sanitized upstream errors never fabricate results", async () => {
  for (const [override, code] of [
    [{ mode: "demo" }, "research_requires_live"],
    [{ apiKey: "" }, "not_configured"],
  ]) {
    const service = createBenchmarkResearch({
      config: { ...config(), ...override },
      fetchImpl: async () => {
        throw Error("must not call");
      },
    });
    await assert.rejects(service.research(req()), errorCode(code));
  }
  const service = createBenchmarkResearch({
    config: config(),
    fetchImpl: async () =>
      new Response("private-key-raw-error", { status: 401 }),
  });
  await assert.rejects(
    service.research(req()),
    (e) => e.code === "upstream_auth" && !e.message.includes("private-key"),
  );
});
test("benchmark HTTP routes share gateway auth and preserve coach health", async (t) => {
  let calls = 0;
  const server = createCoachServer({
    config: { ...config(), token: "test-gateway-token" },
    fetchImpl: async () => (++calls === 1 ? web() : output(plan())),
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
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.deepEqual(await (await fetch(base + "/health")).json(), {
    status: "ok",
    configured: true,
    mode: "live",
  });
  const send = (token) =>
    fetch(base + "/api/benchmarks/research", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(req()),
    });
  assert.equal((await send()).status, 401);
  assert.equal(calls, 0);
  assert.equal((await send("test-gateway-token")).status, 200);
});
