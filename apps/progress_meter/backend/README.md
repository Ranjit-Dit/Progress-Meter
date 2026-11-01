# Progress Meter AI backend

A small Node.js 24 server that connects the Flutter app to the OpenAI Responses API. It has no npm dependencies. The OpenAI key stays on this server and is never sent to Flutter.

## Run locally with live responses

From this folder:

```sh
cp .env.example .env
```

Open `.env` in your editor and set `OPENAI_API_KEY` to your OpenAI project key. Do not paste the key into chat, Dart source, a Flutter build argument, or a public repository. `OPENAI_MODEL` defaults to `gpt-6-luna`; change it to a model available to your project that supports Responses and Structured Outputs.

Start the server:

```sh
npm start
```

It listens on `http://127.0.0.1:8787`. The Flutter AI Coach screen should use this address for local macOS development. `GET /health` reports whether live configuration exists; it does not verify model access or billing. With no key, the server starts normally and coach requests return a helpful `not_configured` error rather than pretending to provide AI responses.

The app requires this backend to be running for live coaching and Testing Lab. A future mobile deployment needs a reachable HTTPS backend; a phone's `127.0.0.1` refers to the phone itself.

## Preview without using an OpenAI key

```sh
npm run demo
```

This deliberately enables `COACH_MODE=demo`. It generates deterministic local examples without calling OpenAI. Every response has `source: "demo"`, `model: null`, and text saying that it is a preview, not an OpenAI response. Demo mode is never an automatic fallback for missing keys, network failures, or rate limits.

## Contract

`POST /api/coach` accepts an `application/json` body:

```json
{
  "question": "What should I focus on this week?",
  "context": {
    "track": "academic",
    "metricLabels": {
      "knowledge": "Understanding",
      "practice": "Practice",
      "consistency": "Consistency",
      "impact": "Outcomes"
    },
    "rubric": "Equal-weight self-assessments from 0 to 100.",
    "history": [],
    "goals": [],
    "benchmark": null,
    "isSampleData": false
  },
  "conversation": []
}
```

Each history item is `{date, score, metrics, note?}` with four metric values. Each active goal is `{title, metric, target, deadline}`. A selected benchmark is `{score, metrics, isExample}`. Dates are ISO strings. Metric keys are `knowledge`, `practice`, `consistency`, and `impact`. Scores are recomputed from the four metrics on the server, so a forged or stale client average is not trusted.

A successful response is:

```json
{
  "reply": "Choose one manageable practice task and review the result next week.",
  "suggestions": [
    {"title": "Practice on three days", "metric": "practice", "target": 65, "days": 7}
  ],
  "source": "openai",
  "model": "gpt-6-luna"
}
```

Suggestions are proposals. Only the student can approve adding them to the app's existing goals. The backend does not write progress files, alter scores, or save goals.

Errors use `{ "error": { "code": "...", "message": "..." } }`. Common statuses are 400 for invalid requests, 401 for a missing gateway token, 403 for a disallowed browser origin, 413 for an oversized snapshot, 422 for a model refusal, 429 for rate limits, 503 for missing configuration or temporary capacity, and 504 for an upstream timeout. Upstream account errors are sanitized and do not return API keys or raw provider messages.

## Limits and privacy

- Request body: 64 KiB; question: 2,000 characters.
- Context: up to 12 dated check-ins and 12 active goals; optional notes are bounded. Names and unrelated saved fields are not forwarded.
- Conversation: up to eight previous user/assistant messages, each at most 12,000 characters. The client should also bound the combined history to stay below the body limit.
- Responses: at most three validated goal suggestions; generated reply at most 8,000 characters.
- Upstream timeout: 45 seconds. Local limit: 15 valid coach requests per minute per IP, with four concurrent requests at most.
- No user prompts, notes, output text, keys, or tokens are written to server logs. The server holds request context in memory only.
- Requests set `store: false` to disable Responses application-state storage. This does not promise zero data retention; OpenAI's separate abuse-monitoring and other data policies still apply. See [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).
- Example and manually entered benchmark scores are always described as unverified; sample check-ins are labeled as sample data. The AI is instructed to explain existing scores, not invent a student's history or promise outcomes.

## Moving beyond one local Mac

The default loopback listener is intended for local development. If `HOST` is changed to a non-loopback address, startup requires `COACH_ACCESS_TOKEN` containing at least 24 characters. When configured, every coach request must use `Authorization: Bearer <COACH_ACCESS_TOKEN>`. This gateway token is separate from the OpenAI key. A shared token is a development/deployment guard, not a replacement for individual student accounts.

Before exposing the server to students, put it behind HTTPS and real per-user authentication, enforce per-user usage budgets, and add centralized quotas if running more than one server instance. The built-in rate limit is in-memory and per process; it resets on restart. Remote client IP headers are not trusted.

Native Flutter requests do not need CORS. Browser origins are rejected unless one exact origin is set in `COACH_ALLOWED_ORIGIN`. There is no wildcard CORS setting. Keep the default closed unless browser support is intentionally added.

## Test without making live API calls

```sh
npm test
```

The tests inject a fake upstream transport, run against a local HTTP server, and check validation, score normalization, secret handling, missing configuration, explicit demo mode, authentication, origin checks, request size, rate and concurrency limits, timeouts, refusals, incomplete output, and malformed output. Network permission for localhost is needed by the test process. They do not verify an actual OpenAI key, billing, or model access.

References: [Responses API overview](https://developers.openai.com/api/reference/overview), [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna).


## Testing Lab endpoints

Testing Lab is available only in live mode. It shares the existing server-only `OPENAI_API_KEY`, configured model, gateway authentication, exact-origin CORS policy, rate limits, concurrency limit, and 64 KiB generation request bound (512 KiB for grading submissions). Demo mode returns `lab_requires_live`; it never invents assessment marks. Local live verification uses synthetic topic/answer text and confirms that a correct reference answer earns marks while blank and grading-manipulation text earns zero. These checks do not establish universal grading accuracy.

`POST /api/lab/generate` accepts `{requestId, topic, learningNotes, track, level, questionCount}`. The optional integer `questionCount` defaults to 4 and accepts 2–20. Request IDs are unique strings of at most 80 letters, digits, underscores, or hyphens. Topics are 1–120 characters; optional notes at most 6,000. Track is `academic` or `career`; level is `beginner`, `intermediate`, or `advanced`. A successful response contains a session ID, random session bearer token, topic/track/level, timestamps, source/model, and the requested public questions. IDs are `q1` through `qN`; the first `ceil(N/2)` test understanding and the rest test application. The default remains `q1`/`q2` understanding and `q3`/`q4` application. Every question has 10 marks, with fixed weights correctness 5, reasoning 3, precision 2. Reference answers and rubric descriptions stay on the server until grading.

`POST /api/lab/grade` accepts `{sessionId, sessionToken, answers:[{questionId,answer}]}` with exactly one answer for each original question. Each answer is at most 6,000 characters; a blank is allowed and forced to zero by the server. Student text is treated as untrusted assessment data. No submitted code, URLs, or tools are executed. Live grading returns criterion marks, detailed feedback, missing concepts, reference answers, and next steps. The server computes overall percentage from marks out of `N × 10` and each dimension from its actual question count times ten; supplied model aggregates are never accepted.

Sessions and generation request IDs occupy bounded memory (100 active sessions, two-hour TTL). Repeated generation with the same request ID and body shares its result; a conflicting body returns `idempotency_conflict`. Repeated grading of identical submitted answers shares its result, including concurrent retries. Changed answers return `already_submitted`. Transient upstream failures can be retried. A missing, expired, or wrong-token session returns `session_expired`. A backend restart expires unfinished assessments; completed results are persisted by Flutter, not this server. No questions, answers, tokens, or key values are logged.

Lab model requests use `store:false`, a 90-second per-call timeout, bounded output tokens, strict JSON schema, and validation of all question IDs, criterion points, and text fields. Generation and grading each use parallel batches of at most four questions (one batch at the default, up to five at twenty). Each batch output is bounded to 256 KiB; Flutter accepts up to 2 MiB for an assembled marked test. Successful batches survive transient failures, so retries only call the model for incomplete batches. Generation request fingerprints include the question count; grading checks the exact saved session IDs/count before model calls. The original answer submission stays locked through retries. Overall qualitative feedback combines each batch review; all per-question feedback and marks are retained. Coach requests retain their original 45-second timeout. Successful cache replays make no additional model call. Per-IP gateway rate limits still apply to retries. OpenAI's retention controls are separate from Responses application-state storage; see the data-control link above.


## Benchmark research endpoints

Benchmark research uses the same live OpenAI key/model, gateway auth/CORS/rate/concurrency limits, and 64 KiB request bound. It requires live mode; demo mode never fabricates research. It uses [Responses web search](https://developers.openai.com/api/docs/guides/tools-web-search) with actual source URLs, followed by strict structured planning. Sources are visible as clickable citations in Flutter. Search covers public professional skills, achievements, education, projects, and role requirements. Ambiguous identity or insufficient relevant sources returns a non-adoptable preview.

`POST /api/benchmarks/research` accepts `{requestId,kind,query,context,postText,track}`. Kind is `person` or `post`; track is `academic` or `career`. Query is 1–300 characters, optional context at most 3,000 characters, and optional post text at most 10,000 characters. The app exposes post text only for post/role searches. URL queries must be public HTTPS. The gateway does not directly fetch arbitrary URLs. A first web-search request uses `tools:[{type:"web_search"}]` and includes `web_search_call.action.sources`. The second request uses only returned research/source IDs plus optional unverified `s0` pasted text. It cannot invent URLs. A ready response contains exactly five milestones (`m1`–`m5`), including at least one assessment and one project. Assessment thresholds (50–100) are recommendations, not scores for another person. Every claim/milestone cites known source IDs. Source IDs/URLs and all structured fields are validated before returning.

`POST /api/benchmarks/review` accepts `{requestId,plan,assessments,projectEvidence}`. The plan is validated; each assessment supplies a unique assessment milestone ID, score, result ID, and completion date. Project evidence supplies a unique project milestone ID, completion flag, notes, and nullable public HTTPS link. Completed projects require notes or a link. The Flutter client selects only the newest exact topic/level/track match for each milestone. It excludes written answers and unrelated workspace data. The server calculates equal-weight readiness as the mean of assessment `min(score/target,1)` and project completion fractions. AI returns qualitative summary, blockers, and next actions only. Projects are explicitly self-reported and links are not inspected. AI cannot change stored completion or the numerical percentage.

Research has a 150-second deadline (up to three web-search tool calls), review 90 seconds. Both use `store:false`, bounded tokens/output, sanitized upstream errors, and no sensitive logging. Successful request IDs coalesce and replay for 30 minutes in bounded memory (100 entries); a reused ID with different content returns `idempotency_conflict`. Failures can be retried. Restarting clears this memory. Readiness is local/deterministic and does not schedule background paid calls. Searching and explicit gap reviews consume API usage.

Controlled tests cover citations, unsupported/private URL validation, unresolved identity, pasted-text warnings, deterministic review, replay conflicts, live-mode errors, upstream sanitation, and shared HTTP authentication. A separate live check verified public professional research, a five-step plan, review, and cached replay using the configured server key without including student records.


## AI progress judgment endpoint

`POST /api/progress/review` accepts `{requestId,track,evidenceKey,assessments}`. Evidence is at most twelve validated Testing Lab summaries, including original IDs, topic, difficulty, question count, completion timestamps, assessed percentages, bounded assessor feedback, and missing concepts. Future results are excluded and score arithmetic is checked. Student-written answers, manual ratings, tasks, routines, profile identity, and goals are not needed. This route shares authentication, origin/rate/concurrency limits and the 64 KiB request boundary. It requires live mode and the server-only OpenAI key.

Responses include an ID, source/model, reviewed timestamp, track/fingerprint, summary, and exactly four AI judgments (`knowledge`, `practice`, `consistency`, `impact`). Scores are nullable 0–100 values with feedback and real cited assessment IDs. Consistency remains null until evidence spans three recorded dates within fourteen days; Outcomes remains null without two same-topic/level/count tests on different days. Eligible scored metrics must cite the necessary dated evidence. These gates do not assign ratings. AI judges formative demonstrated learning; it cannot infer verified work experience, invent evidence, or alter goals. Manual benchmark values are reference targets only.

Requests use Responses Structured Outputs, `store:false`, a 90-second timeout, bounded upstream response/tokens, sanitized errors, and successful-request caching for thirty minutes (100 entries). Changed bodies with reused IDs are rejected. No credentials, prompts, or model output are logged. Seven controlled endpoint tests cover privacy, source validation, missing evidence, gating, retry replay, live mode/errors, and shared HTTP authentication. A synthetic live check also verified all four judgments and cached replay.
