# Architecture

Current scoring policy: all four progress dimensions are AI-only, as enforced by `features/assessment` and `AGENTS.md`. The older manual models/calculations below describe archived records and benchmark reference targets; they must never supply current ratings or goal verification.

## Organization

Progress Meter uses a feature-first Flutter structure. `common` contains shared visual components; `features` contains product behavior. This keeps the familiar common/features convention from the reference ecommerce repository while defining explicit boundaries for this app's scoring and history.

```text
lib/
  main.dart                            Platform storage and bootstrap
  app/
    app.dart                           MaterialApp and theme wiring
    progress_controller.dart           Observable application state and actions
  common/
    app_theme.dart                     Shared colors and Material theme
    widgets/progress_charts.dart       Custom chart and meter components
  features/
    progress/
      domain/
        models.dart                    Validated models and JSON schema
        progress_analytics.dart        Pure calculations and history ordering
      data/
        progress_repository.dart       Repository contract and local JSON adapter
        demo_data.dart                 First-launch examples
      presentation/
        workspace.dart                 Workspace navigation and progress pages
        progress_dialogs.dart          Aspirational goal and benchmark forms
    assessment/
      domain/                          AI judgments, bounded evidence, provenance
      data/                            Judgment HTTP repository
      application/                     Retry, stale response, atomic save guards
      presentation/                    Redesigned Overview and Goals
    notifications/
      domain/                          Preferences and calendar reminder planner
      data/                            Native macOS notification bridge client
      application/                     Permission and schedule reconciliation
      presentation/                    Explicit notification Settings controls
    ai_coach/
      domain/                          Context, replies, goals, repository contract
      data/api_coach_repository.dart   Bounded HTTP client for the coach gateway
      application/coach_controller.dart Memory-only chat, retry, stale-response guard
      presentation/coach_screen.dart   Chat, context opt-in, connection, goal review
    routines/
      domain/                          Weekly templates, dated check-offs, analytics
      presentation/                    Planner and routine editor
    routine_import/
      domain/                          Drafts, table/geometry parser, duplicate identity
      data/                            Native document bridge and XLS/XLSX decoder
      presentation/                    File selection, editable preview, batch save
    benchmark_research/
      domain/                          Sourced plans, evidence, readiness analytics
      data/api_benchmark_repository.dart Bounded research/review HTTP client
      application/benchmark_controller.dart Preview, retry, stale review guards
      presentation/benchmark_research_screen.dart Search, adoption, path evidence
    testing_lab/
      domain/                          Assessment models and history analytics
      data/                            Bounded assessment HTTP client
      application/                     Draft session and grading state
      presentation/                    Tests and marked-paper history
backend/
  benchmark_research.mjs               Public research, citations, plan/review validation
  progress_judgment.mjs               Four AI-only progress judgments
  testing_lab.mjs                     Private answer keys and rubric grading
  server.mjs                           Node.js Responses API gateway
  test/server.test.mjs                 Controlled upstream and HTTP tests
test/
  domain/progress_test.dart
  data/progress_repository_test.dart
  progress_controller_test.dart
  widget_test.dart
  progress_charts_test.dart
```

The first version groups related screens into the `progress` feature because they share the same workspace data. It does not create empty feature modules or adopt a third-party state-management framework before they are needed. `workspace.dart` can be split into overview, journey, benchmark, goal, and settings screens as those areas expand.

## Data flow

```text
main.dart
  → application-support directory from path_provider
  → JsonProgressRepository(progress_v1.json)
  → ProgressController.initialize()
  → ProgressMeterApp → ProgressWorkspace

Form or workspace action
  → validated domain model
  → controller action
  → repository.save(next state)
  → publish committed state through ChangeNotifier
  → ListenableBuilder rebuilds the workspace
```

`ProgressController` receives its repository through its constructor. Tests substitute an in-memory implementation. The controller handles track selection, derived current/previous values, check-ins, goals, benchmark selection, name changes, restore, and clearing the workspace. A save flag prevents overlapping commits. The controller publishes new data only after persistence succeeds, so a failed write keeps the previous state.

Presentation-local state such as page selection, history search, chart range, and comparison choices stays in the workspace widget. Only workspace data is persisted; reopening resets navigation and selects the Academic track.

## Domain model and calculations

`ProgressData` is the aggregate containing immutable lists of check-ins, goals, benchmark profiles, routines, completions, graded Testing Lab results, researched paths, project evidence, and date-specific daily tasks, plus a name and optional selected manual-profile or research-plan ID. Models validate finite 0–100 metric values. Each check-in and benchmark requires all four metrics; incomplete metrics are rejected rather than silently filled with zero.

`ProgressEntry` stores an ID, title, note, track, recorded date, and metrics. `ProgressGoal` stores a track, single metric, target score, deadline, and manual completion flag. `TargetProfile` stores a name, role, initials, track, metric scores, and whether it is an example. Custom benchmarks have `isExample: false` but remain manually entered and unverified.

Both tracks use four equally weighted dimensions. Academic labels are understanding, practice, consistency, and outcomes; career labels are technical skills, projects, consistency, and experience. The underlying metric keys stay stable. The overall score is their arithmetic mean, and comparisons subtract scores to produce percentage-point changes.

`ProgressAnalytics` is independent of Flutter. It filters histories by track and sorts by recorded date with ID as a deterministic tie-breaker, without changing input order. The latest two entries drive the current and previous values. The journey can compare any two entries within one track. Chart range selects the last 4, 8, or 13 check-ins, or all check-ins; it is not a calendar-duration filter.

Benchmark comparison uses the same track and metric keys. One selected profile ID is currently stored for the workspace, so selecting a benchmark in the other track replaces the previous selection. Its gaps can prefill individual metric goals. Completion is a separate user action rather than an automatic inference that a score meets a target.

## Persistence and failure behavior

`ProgressRepository` exposes `load()` and `save(ProgressData)`. `JsonProgressRepository` is the current adapter. `main.dart` supplies a file in the operating system's application-support directory using `path_provider`.

- A missing file returns `null`; initialization then creates and saves sample data once.
- A saved empty workspace loads as empty and is not reseeded.
- JSON writes `schemaVersion: 6` and reads versions 1–6. Missing routine/completion, assessment, research, or daily-task collections in older schemas migrate to empty collections; existing progress and identity are preserved. Unsupported versions and invalid data fail explicitly.
- Saving creates the parent directory, writes a sibling temporary file with a flush, then renames it over the previous file.
- Read errors preserve existing file bytes. Bootstrap displays an error message instead of replacing data with examples.
- Export displays and copies the same JSON schema. Restore parses it and requires UI confirmation before replacing the workspace.
- Start fresh clears entries, goals, benchmarks, routines, completions, assessments, researched paths, project evidence, daily tasks, and selection while preserving the name, after UI confirmation.

The JSON adapter is appropriate for a single local workspace. It does not implement encryption, concurrent multi-process coordination, general migrations beyond the supported schema 1/2/3/4/5→6 path, cloud synchronization, or conflict resolution. The backups UI copies text; it does not open a native save-file picker.

## Platform and verification

The delivered platform focus is macOS, with a deployment target of macOS 12.0. CocoaPods resolves the native `path_provider` plugin; `pubspec.yaml` disables Swift Package Manager because the development environment restricted that route. Android and iOS runners exist but need platform build and device verification. The `dart:io` adapter means web support needs a different storage implementation and bootstrap wiring.

The project declares Dart `^3.13.0`. Development verification uses Flutter 3.47 and Dart 3.13; minimum-version compatibility has not been separately checked.

Run `flutter analyze`, `flutter test`, and `flutter build macos` from the project root. The analyzer and test suite pass. The tests exercise domain validation and calculations, JSON round trips, date ordering and track isolation, disk saves and corrupted data, controller failure behavior, core widget flows, narrow navigation, and chart rendering and semantics. Native macOS debug and release applications were built; the UI was verified while running. The iOS 1.7.1 release was also development-signed, installed, and launched on a physical iPhone. Mobile layout tests cover safe-area insets, short landscape viewports, text scaling, and keyboard access. These checks do not establish complete mobile feature readiness: iOS notification and native PDF/OCR adapters are still absent, and phone AI connectivity needs a reachable HTTPS backend.

The standard Flutter macOS build encountered an Xcode workspace-loader restriction in this environment. `bash tool/build_macos.sh` is the included direct-Xcode fallback: build CocoaPods dependencies first, then the Runner project, aligning dependency product paths with the Runner's derived-data location. Prefer `flutter build macos` in a normal development environment.

## Extension points

**Accounts and real profiles:** implement an API-backed repository and identity service, then add explicit sharing and access controls. Define per-user/workspace data ownership and a synchronization strategy before enabling live peers. Fictional examples and manual benchmarks must remain distinguishable from verified shared profiles.

**Evidence and integrations:** introduce evidence records and rubric versions in the domain. Upload files through a dedicated service with references stored in the model. Keep grade, course, GitHub, project, and portfolio adapters in the data layer. Document how raw values map to normalized scores before combining unlike units.

**Subjects and requirements:** model subjects, courses, skills, and education/career requirements with IDs, units, rubric definitions, and target dates. Historical entries should retain the rubric used at the time so changing a metric does not silently reinterpret old scores.

**Larger features:** split focused presentation screens first. Add use-case services or feature controllers as behavior grows, while keeping calculation code pure and repository dependencies injected. Adopt additional packages when they solve a concrete need; the current `ChangeNotifier` boundary can be replaced without changing domain models or the repository contract.

**Schema evolution:** add explicit version migrations, backup/restore compatibility tests, and recovery paths before changing saved fields. Preserve immutable dated snapshots so future analytics compare actual past states.

## AI coaching boundary

The AI Coach is a separate feature. It receives a snapshot of `ProgressData` and the selected track, constructed with `CoachContext.fromProgressData`. It does not replace `ProgressAnalytics`, JSON storage, or the authoritative score getters. Responses propose a short explanation and at most three typed goals; suggested titles, metrics, targets, and day offsets are validated. The existing goal dialog provides a review step before `ProgressController.addGoal` persists a suggestion.

`CoachController` keeps a bounded outgoing conversation context, loading/error state, and retry data in memory. Clearing the conversation invalidates pending responses; changing tracks clears the controller and remounts the screen so note sharing and draft text reset. Toggling note sharing clears the conversation. Returning to the same conversation preserves its explicit note-sharing setting; the controller also clears prior context if that setting changes. Deleting data, restoring a backup, starting fresh, or retargeting increments the progress controller’s ephemeral context revision, which invalidates old coaching snapshots and pending replies. No API call occurs simply from opening a profile; the coach screen checks service health but sends progress only after the student sends a question or chooses a prompt.

`ApiCoachRepository` talks to the app's backend, not directly to OpenAI. It accepts HTTPS services, plus HTTP loopback and Android emulator development addresses. Redirects are not followed, responses and requests are bounded to 64 KiB, and HTTP failures map to sanitized public messages. Runtime backend access tokens are kept in memory; the OpenAI key exists only in the backend environment. macOS debug and release entitlements include outgoing network client access. Android has Internet permission; mobile builds and HTTP development configuration still need platform verification.

The backend validates and whitelists context, recomputes arithmetic means, bounds requests and concurrency, and calls the OpenAI Responses API with strict structured output and `store: false`. It handles refusals, incomplete responses, malformed output, unavailable credentials, and timeouts. The model and API key are server environment settings. Demo mode is an explicit independent configuration with `source: demo`; a failing live request never becomes a fake successful AI response.

The local backend key/model have been verified through a synthetic live Testing Lab assessment. Real credentials remain outside source archives. Controlled tests verify the live request/response contract; an end-to-end smoke check exercises the actual Dart HTTP client against the Node service in demo mode. Live verification does not establish universal grading accuracy or production readiness. Public multi-user hosting requires identity/session verification and per-user quotas beyond the included private gateway token and in-memory rate limits.

## Weekly routines

The `features/routines` module owns validated `RoutineItem` and `RoutineCompletion` models, pure `RoutineAnalytics`, the reusable add/edit dialog, and a focused planner screen. `ProgressData` contains immutable routine lists and completion lists in schema 6. All existing copies of application data preserve these fields by default. The JSON repository and backup/restore UI keep routines with the rest of the workspace; old schema 1 backups remain readable.

A routine has a fixed kind (class session or meal), a title, a set of weekdays (Monday 1 through Sunday 7), and a local minute-of-day. Class intervals must end later on the same day; meals have one planned time. Recurrence is weekly without semester boundaries or exception dates. Class conflict detection uses shared weekdays and half-open time intervals, so back-to-back classes are allowed. Conflicts are informational, allowing intentionally overlapping schedules to be saved.

Completion records reference an existing routine ID plus a canonical local `YYYY-MM-DD` date. A controller toggle checks the actual saved template, rejects new completions in the future or on an unscheduled day, and changes only the selected date. Removing an existing completion remains possible after recurrence changes. Editing preserves completions, including dates no longer in the repeat days; the daily view labels those earlier records. Deleting a routine cascades only its own completion records after UI confirmation. Current recurring template labels and times are used when viewing records; full historical template snapshots are a future extension.

The same atomic controller commit path persists routines and keeps prior data on failed saves. Tests cover legacy migration, disk restart, repeat-day sorting, conflict intervals, date validation, independent date check-offs, failed-save recovery, CRUD forms, actual time input, overlap warnings, and narrow layouts. The routines are global personal schedules, independent of academic/career track filters. The coach context uses an explicit whitelist and excludes routines, menus, rooms, instructors, and check-offs. No backend dependency, notifications, or calendar synchronization was added.


## Local document imports

`RoutineImportService` isolates file selection and extraction from presentation. `LocalRoutineImportService` reads a user-selected file through `file_selector`, validates its size/signature, and retains only a basename and bytes for that extraction. It uses the macOS `progress_meter/document_reader` method channel for PDFs/images and `SpreadsheetReader` for Excel. It makes no HTTP requests. Native file access uses the user-selected read-only sandbox entitlement.

The Swift reader in `MainFlutterWindow.swift` performs PDFKit text extraction or ImageIO/Vision OCR on a background serial queue. It returns normalized top-left word bounds, page sizes, OCR state, and warnings. PDFs without useful text are rendered for OCR; images are downsampled before recognition. Byte, page, pixel, and token limits bound the work. Dart validates the native response and parses the geometry in an isolate. Native errors map to public messages rather than exposing raw file paths.

`SpreadsheetReader` bounds compressed and expanded data, sheet/cell dimensions, and cell text. It reads workbook values in an isolate, expands merged cells, and preserves text formula caches as plain values before the Excel decoder processes them. No formula evaluation or macro execution occurs. `ScheduleParser` handles labeled rows, weekly grids, and page-positioned text, with explicit aliases and repeated-column inference for damaged OCR headers. It produces at most 200 `ImportDraft` values, leaving uncertain or absent required values unset. The preview permits corrections and selection without mutating persistent state.

`ProgressController.importRoutines` checks semantic identities against existing and newly selected routines, subtracts covered weekdays, assigns new IDs, and commits the entire batch once. A failed save publishes no changes. Undo removes only the returned new IDs and their completions. Routine imports neither change progress scores nor invalidate or add content to AI Coach. The current schema needs no change because only validated routine templates are persisted; original documents, parsed identity fields, and raw OCR data are discarded.

Tests use synthetic documents/workbooks and injected services. Native smoke checks additionally exercise a user-selected searchable PDF and a rendered timetable image on macOS. The private source document and extracted raw data are excluded from the source archive. Add platform-native PDF/OCR adapters behind the same service contract for mobile support.


## Testing Lab

`features/testing_lab` separates strict domain models, date-based analytics, a bounded HTTP repository, a memory-only session controller, and the presentation flow. Shared `ProgressTrack`/`MetricKind` definitions live in `progress_types.dart` and are re-exported by `models.dart`, avoiding a dependency cycle between assessment results and the persistent workspace aggregate.

`ProgressData` writes schema 6 and reads schemas 1, 2, 3, 4, 5, and 6. Completed `LabResult` records include the public questions (2–20, default four), written answers, criterion marks, references, feedback, next steps, source/model, and completion timestamp. Scores are recomputed from criterion marks when loading, and inconsistent supplied aggregates are rejected. All copy/update paths retain results. `recordLabResult` appends one stable session ID atomically and is idempotent; clear/restore operates on the full aggregate. Session bearer tokens and original learning notes are never serialized. Existing routine and progress records are preserved during legacy reads.

`LabController` owns generation request IDs, an in-memory question set, draft answers, immutable submitted answers, busy/error state, the latest grade, and save status. Pending replies are ignored after clear/disposal. Grading locks the original submission for reliable retries. Request size is checked before locking so oversized UTF-8 answers remain editable. A successful grade is saved through an injected `ProgressController.recordLabResult` callback. A local save failure retains the paper and retries persistence without paying for another model grading request. Workspace navigation retains the controller, while changing track/server or replacing private data invalidates ephemeral assessment state with appropriate draft guards.

The Node gateway's `testing_lab.mjs` owns hidden reference answers and rubric descriptions. Generation and grading use Responses Structured Outputs, explicit instructions to treat student content as untrusted data, fixed weights, and strict response validation. The requested question count (integer 2–20, default four) determines server-assigned IDs `q1`–`qN` and dimensions: the first `ceil(N/2)` understanding, the remainder application. Every question has ten marks. Overall and dimension scores divide earned marks by their respective actual maximum marks; odd-sized tests do not simply average the two dimension percentages. Generation/grading run parallel batches of up to four questions (at most five model calls per operation); successful batches are retained through retries. Submitted IDs/count must exactly match the saved session before any grading call. Blank-answer zero marks and all percentage arithmetic are deterministic server rules. Bounded session memory and idempotent request/submission caching avoid exposing keys or charging for successful retry replays. The gateway is a private local development service, not a multi-user exam authentication system.

Lab history is separate from the manual self-assessment rubric. The overview promotes assessed learning without reinterpreting a quiz as projects or work experience. Understanding and application percentages come only from assessed answers. Recorded completion dates are evidence for AI judgments. The legacy participation percentage utility is not used as the current Consistency rating. Comparable history uses the same normalized topic, level, track, and question count; fresh generated questions can still differ in difficulty. Coach context continues to exclude assessment questions and written answers.

Tests cover legacy migration, score/ID validation, private-token exclusion, exact answer preservation, session expiry and stale responses, idempotent persistence, failed-save retry, rubric grading bounds, hidden keys, prompt-injection instructions, blank zero rules, authenticated HTTP, cache replay, narrow layouts, and marked-paper flows. Synthetic live model verification supplements the controlled tests. Variable tests retain the same questions list in schema 6, so legacy four-question results round-trip without a migration. Grading payloads allow 512 KiB for twenty Unicode answers and the client accepts 2 MiB assembled results; generation and other gateway routes retain 64 KiB bodies. The client timeout is 115 seconds while each parallel model batch has a 90-second limit. The macOS app keeps the existing outgoing network entitlement; no key is embedded in Flutter.


## Researched benchmark paths

`features/benchmark_research` owns validated public sources, source-linked claims, five-step `ResearchPlan` records, project evidence, deterministic readiness analytics, the HTTP repository, and its controller/screen. `ProgressData` schema 6 persists adopted ready plans and project evidence. Search previews and AI gap reviews stay in memory. Older schema 3 assessment records are preserved on migration. Adoption selects the path and clears the active manual benchmark in one atomic save. Selection/removal never deletes assessment history. Removal cascades only the path's project evidence.

Research is a two-stage backend operation: Responses web search returns professional research and real citation/source URLs; a strict structured-output request turns that research into a validated plan. Only actual search source URLs are accepted, with optional `s0` representing explicitly unverified pasted post text. Client and server validate public HTTPS links and citation IDs. The gateway does not directly fetch arbitrary user URLs. Unavailable/private pages and ambiguous identities are surfaced, not filled with invented facts. Ready plans require exactly five milestones, including assessment and project kinds; unresolved plans cannot be adopted. Target percentages describe recommended practice-test thresholds, not a researched person's ability.

`BenchmarkAnalytics` matches the newest non-future Lab result by normalized topic, exact level, and track. An assessment milestone contributes `min(score / target,1)`; a project contributes 1 only when saved as completed with notes or a public evidence link. The equal mean across the five milestones is readiness. Project evidence is student-reported. Manual check-in scores never participate. The same formula runs on the server before a gap review; the model returns only qualitative feedback, and the client rejects an inconsistent percentage. Evidence fingerprints hide stale reviews after an assessment or project change.

The roadmap action generates a Testing Lab session for the exact milestone topic/level after existing draft/unsaved-grade guards. Retargeting invalidates coach context and AI reviews without erasing unfinished Lab answers. A separate ephemeral `labContextRevision` resets tests only when relevant private data is replaced/removed. Changing tracks or service connection retains the existing assessment guard behavior.

Research/review use the shared authenticated gateway and server-only OpenAI key. Requests are limited to 64 KiB and client responses to 256 KiB, with no redirects. Research timeout is 150 seconds, review timeout 90 seconds, and the client allows 165 seconds. Successful request IDs are cached for 30 minutes (100 entries); changed bodies with reused IDs are rejected. Research sends query/context/post text; reviews send the adopted plan, matched marks/IDs/dates, and project notes/links. Written test answers and unrelated workspace data are excluded. Responses use `store:false`; no prompts, keys, or output text are logged. Opening a citation uses `url_launcher` in the external browser. Readiness updates require no model call; paid gap reviews are explicit user actions.

Tests cover real-source validation, ambiguous identities, unsafe URLs, legacy preservation, atomic adoption failure, exact assessment matching, deterministic readiness, stale reviews, API privacy, auth/cache behavior, clickable citations, project evidence, Lab launch, and narrow layout. A live synthetic check additionally verified web research and structured planning for a public professional, plus model feedback with deterministic readiness and cached replay.


## Daily tasks

The routines feature also owns `DailyTask` and `DailyTaskAnalytics`. Tasks are separate from weekly `RoutineItem` templates and import parsing. A task has a stable ID, title, canonical local `YYYY-MM-DD` date, optional minute-of-day, notes, and completion flag. Validation rejects invalid calendar dates, out-of-range times, missing titles, and duplicate saved IDs. The daily list matches the exact date and sorts unfinished items first, then by time with untimed items last, then stable ID. Tasks do not recur weekly or carry over automatically.

`ProgressData.dailyTasks` is immutable and included in `copyWith`, JSON backups, restore, and Start fresh. Schema 5 reads schemas 1–4 with an empty task list while preserving their applicable routines, assessments, and researched targets. The atomic repository commit publishes no task changes on failure. Controller actions add/edit/delete one task or toggle its current saved state. New completions on future dates are rejected; undo remains possible. Moving a completed task to another date resets its completion. Tasks are local to the workspace and shared across tracks, without changing scores or appearing in AI payloads.

`RoutinesScreen` displays task indicators in the date navigator and a checklist in both Daily routine and Daily tasks. Focused task-dialog and checklist widgets handle optional time, notes, edit/delete controls, future planning, done/to-do counts, and error recovery. A failed dialog save retains typed details. Overview/Settings counts and restore/clear descriptions include tasks. Core and widget tests cover date isolation, future completion guards, rescheduling, legacy migration, disk round trips, save failure/concurrency, privacy, form validation, deletion confirmation, and narrow layout.


## AI-only dashboard and goal policy

`features/assessment` replaces current manual-score surfaces with `AiProgressJudgment` records. The four stable metric keys map to Understanding, Practice, Consistency, and Outcomes across both tracks. Every field is nullable when evidence is insufficient; null never becomes zero. `AiEvidenceSnapshot` takes up to twelve newest non-future Lab summaries with local-offset timestamps, omitting written answers and unrelated data. A SHA-256 fingerprint binds judgments to exact evidence. Client/server validate numeric ranges, source IDs, and eligibility: consistency requires three recorded dates in fourteen days; outcomes requires a same-topic/level/count pair on distinct dates. Those gates never calculate or award a score.

`AiJudgmentController` retains retry IDs and pending successful results after a failed local save. Changed evidence prevents stale judgments from saving or displaying. `ProgressController.currentJudgment` and `goalAchieved` are authoritative for the redesigned Overview/Goals. Goal thresholds are editable aspirations; manual goal-completion writes and new manual-score entry writes are rejected. Legacy records/flags remain readable in backups and the explicitly labeled journal. Lab results still expose their own AI rubric marks; current progress ratings come from the separate AI review. Coach snapshots exclude manual ratings and only use a current complete AI judgment, with bounded AI-detail opt-in.

Schema 6 adds immutable `aiJudgments` and `reminderSettings`, reading versions 1–5 with empty judgments and disabled reminders. Assessment deletion removes dependent judgments. Restore, clear, JSON backups, privacy exclusions, and atomic save failure behavior cover both new fields. Tests verify absent evidence, stale replies, AI-only goal attainment, protocol validation, legacy compatibility, and narrow layouts. Live synthetic verification exercises the configured model without student records.

## Native timed reminders

The notifications feature uses a pure calendar planner, a mockable method-channel service, a schedule controller, and a Settings card. `LocalReminderBridge` in `MainFlutterWindow.swift` wraps `UNUserNotificationCenter`, requesting alert/sound authorization only after the enable action. Status checks never prompt. Weekly class/meal requests use repeating calendar triggers; timed daily tasks use one-off triggers and skip completed/expired items. Lead minutes can cross the previous calendar day/week. Untimed tasks and date-only goals have no reminder.

Reminder IDs use an app-owned prefix. Reconciliation replaces stable IDs, cancels only removed app-owned requests, and runs after relevant saved changes or app resume. A maximum of 64 pending requests prioritizes dated tasks and exposes any truncation. Permission denial and schedule errors have explicit recovery controls. Native delivery continues while the app is closed; Foreground delegate callbacks allow banners/sounds, and notification selection activates the app. No notification content reaches OpenAI. macOS is implemented; mobile adapters remain future work. Tests cover calendar boundaries, lead fallback, completion/deletion, stable IDs, limits, permission behavior, persistence, and responsive controls.


## Personal AI connections (1.8.0)

`features/ai_connection` keeps personal-provider configuration outside `ProgressData`. A user-entered API key exists only in the active app session. It has no JSON representation, is masked in the form, and is absent from progress backups and builds. The existing backend adapter continues to accept a gateway access token only; developer-owned provider keys remain on that backend.

`AiProviderClient` sends direct HTTPS requests to fixed official provider presets or an explicitly entered custom OpenAI-compatible endpoint. OpenAI Responses, Anthropic Messages, Gemini content generation, and compatible Chat Completions have separate wire adapters. Credentials are headers, never request-body fields or URL query parameters. Redirects are rejected, requests/responses are bounded, and timeouts, refusals, truncation and provider errors become sanitized typed failures. Provider schema subsets are adapted while domain validators keep full bounds. Exact credential echoes in returned text and citations are removed or rejected.

Personal Coach, Lab, Judgment and Benchmark repositories implement the existing interfaces. They record source `ai` with the provider/model audit identifier, preserving legacy `openai` records. Questions, private references, session tokens, request fingerprints and retry caches stay in bounded memory. The Lab validates session identity and every submitted question, applies the same 5/3/2 rubric, enforces blank-answer zero, and retains valid batches so retries do not repeat successful calls. Progress judgments require the same assessment fingerprint, citations, consistency dates and comparable outcomes evidence as the backend.

Connection changes recreate all AI controllers. Busy requests and unsaved graded results prevent changes; discarding an unfinished test requires confirmation. Private workspace resets close personal repositories to clear cached answers and references. Switching to the app backend drops the personal connection; keys are never restored from JSON. Personal configuration health checks do not automatically incur API usage; the explicit Test connection action uses a small structured request.

Public web research currently uses supported OpenAI search models and citations returned by actual tool calls. Other personal providers can produce paths from explicitly unverified pasted post text and review stored paths. They cannot fabricate a browsing capability. A backend review accepts personal-provider roadmap provenance without rewriting it.

Validation: 233 Flutter tests, 53 backend tests, analyzer clean, iOS and macOS releases built and signatures verified. Live synthetic OpenAI checks cover Coach, question generation, strict grading and evidence-gated progress judgments. Other provider adapters are verified with mock HTTP responses and official API schemas; no live account claims are made for those providers.
