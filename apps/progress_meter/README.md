# Progress Meter

A Flutter workspace for students to demonstrate academic and career learning, receive AI judgments, and follow goals and sourced benchmark paths. The app uses local device storage and has a responsive layout for smaller screens. See the iPhone support limits below.

## What works

- **Overview:** an evidence-first dashboard with four AI judgments, assessment history, AI-verified goals, researched targets, and today’s planner.
- **My journey:** a read-only legacy journal of earlier self-ratings, with search, comparison, and deletion. New learning evidence comes from Testing Lab.
- **Benchmarks:** research a public person, post, or job role with AI web search; review cited findings, adopt a five-step learning path as your target, and track readiness from Testing Lab results and project evidence. Manual benchmarks and fictional examples remain available.
- **Goals:** choose an aspirational AI score and deadline, track progress from current AI judgments, and filter verified goals or goals needing evidence. There is no manual completion checkbox.
- **Routines:** daily task checklists, weekly class timetables, and food plans, with editable subjects/menus, times, repeat days, and dated check-offs. Import images, PDF timetables, and Excel workbooks with a review before saving.
- **Testing Lab:** live AI questions and strict rubric grading, automatically saved assessed history, marked answers, feedback, and variable-length assessments. Overall progress dimensions are judged separately by AI.
- **AI Coach:** ask about recent progress, create a weekly plan, and review suggested goals before saving. Legacy self-ratings are excluded. AI review details are included only by opt-in.
- **Settings:** connect a personal AI provider, edit your name, configure timed notifications, understand AI evidence requirements, copy a JSON backup, restore one, or start with an empty workspace.

Changes save automatically on this device. A first launch creates sample data so the screens can be explored immediately. Choose **Settings → Start fresh** to remove all check-ins, goals, benchmarks, routines, daily tasks, routine check-offs, Testing Lab results and written answers, researched paths, project evidence, AI judgments, and reminder preferences, including personal additions; your name is retained. An intentionally empty workspace stays empty on subsequent launches.

## Run on macOS

Install a current stable Flutter SDK, Xcode with its command-line tools, and CocoaPods. The project uses CocoaPods for its native plugin; Swift Package Manager is disabled in `pubspec.yaml` because of restrictions encountered in the build environment. The macOS deployment target is 12.0.

From this directory:

```sh
flutter pub get
flutter run -d macos
```

Check and build:

```sh
flutter analyze
flutter test
flutter build macos
```

If the standard Flutter build encounters the Xcode workspace-loader restriction observed in this environment, use the included direct-Xcode fallback:

```sh
bash tool/build_macos.sh
```

The fallback builds CocoaPods dependencies first, then the Runner project with matching build-product paths. Prefer the standard Flutter command in a normal development environment.

The fallback defaults to Release; use `bash tool/build_macos.sh Debug` for a debug build.

The release app is generated under `build/macos/Build/Products/Release/Progress Meter.app`. A release build does not provide distribution signing or notarization.

Development and verification used Flutter 3.47 with Dart 3.13. The project requires Dart 3.13 or newer within Dart 3.x. An Android runner is included, but Android builds and device behavior remain unverified. This implementation uses `dart:io` persistence and does not currently target the web.

## Run on iPhone

The iOS **1.8.0+11 Release** app was built and development-signed in Xcode, passed strict code-signature verification, and was installed on a physical **iPhone 15 Pro Max running iOS 27.0**. Xcode confirmed that the updated app launched. The new icon, safe-area header spacing, and Goals layout were visually checked on the connected phone. Individual iPhone features still need device testing.

Connect and unlock the iPhone. In **Xcode → Settings → Accounts**, add your Apple account if needed. Open `ios/Runner.xcworkspace`, select **Runner → Signing & Capabilities**, enable automatic signing, and choose your development team. Select the connected iPhone as the destination. The deployment target is iOS 15.0.

Use the matching Flutter SDK from this project’s requirements, then run a Release build. Replace `YOUR_IPHONE_DEVICE_ID` with the identifier shown by `flutter devices`:

```sh
flutter pub get
flutter devices
flutter run --release -d YOUR_IPHONE_DEVICE_ID
```

Alternatively, use Xcode with the Runner scheme’s Run build configuration set to **Release**. If iOS blocks launch, trust your developer profile under **Settings → General → VPN & Device Management**, then open Progress Meter again.

iPhone support currently has these limits:

- **Choose personal AI or a reachable backend.** Personal AI connects directly to the selected HTTPS provider without requiring the Mac. In backend mode, `http://127.0.0.1:8787` points to the iPhone itself; configure a remote HTTPS backend in Connection settings instead.
- **Native timed reminders and image/PDF extraction are not implemented for iOS.** Excel decoding is portable Dart code, but iPhone file picking and import behavior still need device verification.
- **Mac data does not sync automatically.** Each device has its own workspace. Use Settings’ JSON backup export and restore to transfer saved data manually.

### Responsive layouts and app icons

The workspace respects the status bar, Dynamic Island, home indicator, and landscape side insets. Compact headers show the current page, track tabs expand across the available width, and navigation scrolls on shorter screens. Cards and form actions wrap with larger text; goal, routine, task, and import dialogs remain scrollable with a keyboard or in landscape. Eight widget checks cover 320–430px portrait widths, landscape, text scaling up to 2×, and form actions above the keyboard.

The native iOS, macOS, and Android icons use a forest-green progress gauge and rising path. The SVG source, preview, and regeneration instructions are in `assets/branding/`; `tool/branding/generate_app_icons.swift` produces every native size.

## Connect your own AI model

Open **Settings → Your AI model → Connect my AI**, or choose **Your AI model** in Coach, Testing Lab, or Benchmarks. Select OpenAI, Anthropic, Google Gemini, DeepSeek, Groq, OpenRouter, or **Custom OpenAI-compatible**. Enter a model ID available to your provider account and paste its API key. Custom services need their HTTPS API base URL, for example an endpoint ending in `/v1`, rather than the full `/chat/completions` resource URL.

**Test connection** makes a small API request to verify the key, model, and required structured-output support. Choose **Use my API key** to activate it for Coach, Testing Lab, AI progress judgments, and roadmap reviews. No backend is needed in this mode. API usage is billed by the selected provider; support depends on that model’s JSON capabilities and context/output limits.

Keys are masked, held only in app memory, and sent only to the selected HTTPS provider. They are excluded from saved progress, JSON backups, logs, and distributed app builds. Enter the key again after quitting the app. Switching back to **Use app backend** forgets the personal connection. Preset providers use fixed official endpoints; custom endpoints are explicit and redirects are rejected. Changing connections cannot interrupt a busy request or discard an unsaved graded result.

Public person/link research in personal mode requires a supported OpenAI web-search model. Other providers can analyze pasted post text, explicitly marked unverified, and review existing roadmaps. No unsupported model may fabricate web citations or award invalid grades. Progress evidence gates and the AI-only scoring policy apply to every provider.

OpenAI uses its [Responses structured-output API](https://developers.openai.com/api/docs/guides/structured-outputs); Anthropic uses its [Messages structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs); Gemini uses its [content generation API](https://ai.google.dev/api/generate-content). Provider grammar constraints are adapted where needed and the app validates full rubric marks, score bounds, and citations before saving. OpenAI Coach, question generation, grading, and progress judgments passed a live synthetic-data check. Other provider protocols have mock HTTP coverage, not live account verification.

## Use the app backend

The default backend option uses a small Node.js service so its developer-owned OpenAI key never ships in Flutter. Personal AI mode is a separate direct connection using the user’s own session-only key. Node.js 24 or newer is required. The backend has no npm package dependencies.

1. Open `backend/.env` in this workspace. When using the source archive, first copy `backend/.env.example` to `backend/.env`.
2. Set `OPENAI_API_KEY` to your OpenAI project API key. Keep `COACH_MODE=live`; select an available model through `OPENAI_MODEL` if needed. Keep this developer key on the backend; never paste keys into chat. Personal keys belong only in the app’s dedicated personal AI form.
3. From the backend folder, run:

```sh
npm start
```

4. Open **AI Coach** in the app. The default coach URL is `http://127.0.0.1:8787`, suitable for this Mac. Ask a question or select a prompt. A goal is saved only after **Review goal → Create goal**.

To preview the interaction without an API key or API charges, run `npm run demo` instead. Demo responses are deterministic examples, explicitly labeled in the app. The server never silently falls back to demo mode after a live request fails.

In backend mode, the Flutter app and backend must both be running for coaching. Personal AI mode connects directly to its provider. Progress tracking and local backups work independently. A remote coach service needs HTTPS; use **AI Coach → Connection settings** to change the URL and optionally enter a backend access token for this session. This token is separate from your OpenAI key and is kept in memory. Do not embed shared gateway tokens in build arguments. For a permanent URL default, use `--dart-define=COACH_API_URL=https://your-coach.example` when building or running Flutter.

Coach requests include the selected track, the current complete AI judgment when available, up to 12 goals that have not reached their AI-judged target, selected benchmark reference thresholds, and recent conversation messages. Legacy self-ratings, routines, tasks, written test answers, and profile names are excluded. Missing or partial AI judgments do not become zero scores. Opt-in shares a bounded AI review summary, rather than old personal reflection notes. Chat does not award or change scores. The backend uses `store:false`; see [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).

The backend defaults to a loopback listener with validation, timeouts, rate limits, and restricted browser origins. Exposing it to students requires real per-user authentication, HTTPS, and usage budgets. See [backend/README.md](backend/README.md) for setup, endpoints, and deployment limits.

Backend checks:

```sh
cd backend
npm test
```

Live benchmark checks have verified public web research, five-step planning, deterministic progress review, and retry replay. A live Testing Lab smoke check has verified question generation and strict grading with the locally configured OpenAI key and model. It used synthetic learning content, not student records. Coach parsing and error paths are also tested with controlled upstream responses. The real key stays in the local backend configuration and is excluded from the source archive.

## Research a benchmark and follow a path

Open **Benchmarks**, choose **Person** or **Post / role**, and enter a name, keywords, or a public HTTPS link. Add an organization or field to distinguish people with similar names. For a post that cannot be read publicly, you can paste its text; that text is labeled unverified. Choose **Research and build path**. The live backend searches public professional sources, then creates a structured preview with clickable citations alongside claims and milestones. It does not access private accounts or search personal/sensitive information. Ambiguous names and insufficient sources need more context before a path can be adopted.

Review the findings and choose **Adopt path and set target**. A ready path has exactly five ordered milestones, including assessed skills and tangible projects. Thresholds and steps are AI recommendations; they are not measured ability scores for the person. Adoption saves the path locally and selects it as your target. You can keep several paths, switch the selected target, and remove a saved path without deleting assessment history. Selecting a manual benchmark replaces the active researched target, and selecting a researched path replaces the active manual target.

**Readiness** updates automatically as evidence changes. Each milestone has equal weight. For an assessment milestone, the latest saved Testing Lab result with the same topic (ignoring case/extra spaces), difficulty, and track contributes `min(score / target, 1)`. Future-dated results are excluded. **Test this skill** opens Testing Lab and generates a test for that exact topic and level. A project contributes 1 after you mark it complete and save notes or a public evidence link; otherwise it contributes 0. Project completion is self-reported, and links are not independently verified. The percentage is the average of these five fractions. Manual self-ratings do not enter this calculation. Readiness measures completion of this learning path; it does not establish equivalence to another person.

Choose **Review my gaps with AI** for feedback based on the path, current marks, and project evidence. The server calculates the percentage; AI cannot award completion or replace the calculation. Reviews become stale when evidence changes. Readiness changes locally without an API call; searching and requesting a review use your OpenAI account. There is no background web monitoring or automatic paid review.

Research requires the same running live backend and connection settings as Testing Lab. Search requests share your query, optional context, and pasted post text. Reviews share the saved path and citations, matched assessment marks/IDs/dates, and project notes/links; written test answers, routines, unrelated history, and your workspace name are excluded. AI uses public [web search](https://developers.openai.com/api/docs/guides/tools-web-search) and structured output with `store:false`. Actual returned search URLs are retained as citations. Successful retries are cached in backend memory for 30 minutes; restarting the backend clears that cache. Your OpenAI key stays in `backend/.env` and is excluded from delivery archives.

## Testing Lab

Open **Testing Lab**, or choose **Test what I learned** on Overview. Choose Academic or Career, enter the topic you learned, choose Beginner, Intermediate, or Advanced, and optionally describe what you studied. **Generate test** sends that topic and optional learning notes to your configured OpenAI backend. The **Number of questions** field defaults to **4**, automatically producing two understanding and two application questions. Choose any whole number from **2 to 20** for a shorter or longer test; **Use default (4)** resets it. Odd counts give understanding the extra question. Each test includes both areas. Answer the chosen set, then submit once for judgment and feedback. Write your reasoning, calculations, or code as text; no self-rating sliders are used.

Choose **Submit for strict grading** when ready. Each question has 10 marks: correctness 5, reasoning 3, precision 2. The examiner is instructed to demand complete, justified work, accept correct alternative methods, explain deductions, and give zero for blank or irrelevant answers. It does not award marks for confidence or length. Blank submissions ask for confirmation. The server computes the overall percentage from marks earned out of `question count × 10`, and computes each dimension from its actual number of questions. For example, seven questions have 70 marks, with four understanding and three application questions. The overall score weights every question equally, including odd-sized tests. The app validates those totals against the individual marks. Half-point percentages are retained.

The marked paper includes the submitted answer, criterion marks, missing concepts, feedback, a reference answer, and next steps. Completed results save automatically on this device; a failed save keeps the graded result available for **Retry saving grade**, without another OpenAI request. History supports reviewing old marked papers and comparing earlier tests on the same topic, difficulty, track, and question count. Generated questions can vary, so these are practice comparisons rather than standardized examination results. The model assesses written work; it does not execute code or verify external projects or employment experience.

Saved assessment dates and marks supply evidence for the separate AI judgment. Test results display their AI rubric marks for understanding and application. They no longer display an automatically calculated consistency rating. Use **Overview → Ask AI to judge progress** to ask AI to judge all four progress dimensions.

Testing Lab uses either the personal provider or a backend running in **live** mode with its OpenAI key. The current Mac uses `http://127.0.0.1:8787`; start it with `npm start` from `backend/` after restarting your computer. AI Coach, Testing Lab, AI progress judgments, and benchmark research share connection settings. Demo coaching does not create assessment grades. Topic, learning notes, questions, rubrics, and submitted answers are sent to the selected provider (or OpenAI through the backend) for the requested generation or grading; unrelated progress, routines, profile names, and student documents are not sent. These requests use [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses). AI feedback is formative and can be mistaken; review disputed explanations against your course material.

Private references and rubrics stay in bounded memory until grading: on the backend in backend mode, or in the app in personal mode. An unfinished test lasts up to two hours and expires if the backend restarts. Draft answers remain in the app's memory while navigating, but are not recovered after quitting. Completed question papers, answers, marks, and feedback are included in local JSON backups; original learning notes and session bearer tokens are not saved. Longer tests are generated and graded in batches of up to four questions, so they can use more API requests than the default test. Successful generation and grading batches are retained for retry, and a submitted test cannot be regraded with changed answers. Starting another test generates a fresh question set.

## Food, class routines, and daily tasks

Open **Routines** in the sidebar, or **Open routines** on the overview.

- **Daily routine:** select a date or browse weeks, see meals and classes in time order plus tasks for that date, mark a meal done, or mark a class attended. Check-offs belong to that date rather than every repeated occurrence. Future dates are for planning; they can be checked off on the day or afterward.
- **Daily tasks:** choose **Add task** to record what needs doing on the selected date, with an optional time and notes. View the checklist in **Daily routine** or the **Daily tasks** tab, mark items done, or edit/delete them through **Manage task**. Tasks belong to one date and do not repeat weekly or automatically move to another day. Future dates are for planning; complete tasks on their day or afterward. Moving a completed task to another date marks it to do again.
- **Class routine:** add a subject, start/end time, repeat days, room, instructor, and notes. The weekly view previews each day's classes. Overlapping class intervals are flagged but do not prevent saving, so you can review and adjust them.
- **Food routine:** plan breakfast, lunch, dinner, snacks, or custom meal names, with a time, menu notes, location, and repeat days. New meals default to every day; all times and days are editable. The app does not prescribe nutrition or calculate calories.
- Use each item's **Manage → Edit routine** menu to change its weekly template. Previous check-offs are kept; a completed date removed from the current repeat days is shown as an earlier check-off. Edits apply to the recurring plan for all weeks; historical schedule titles and times are not independently snapshotted.
- Deleting a routine asks for confirmation and removes its check-off history. Other routines are kept. Export a backup first if you want to preserve it.

Routines and daily tasks are shared across the academic and career tracks and use your device's local calendar/time. They do not change progress scores or get sent to AI Coach. Daily task titles and notes stay in local storage and backups. Timed reminders are optional in Settings. There is no OS calendar integration. Existing installations start with empty routine plans rather than made-up personal schedules.

## Import a timetable or meal plan

Choose **Routines → Import file**, select **Class routine** or **Food routine**, and choose an image, PDF, or Excel workbook. The app extracts entries and fills in the title, repeat days, times, room, instructor, and menu/session notes when these fields can be identified. Review the preview, use the pencil to correct any row, then choose **Import routines**. Missing days or times remain blank and must be corrected before that row can be selected. The final save adds all selected routines together; an Undo action can remove that batch.

The macOS app uses PDFKit for searchable PDFs and Apple Vision for local image/scanned-page OCR. Supported images are PNG, JPEG, HEIC/HEIF, and WebP. PDF/image files must be at most 20 MB, PDFs at most 12 pages, and image pages at most 100 megapixels. English printed text works best. The parser supports common row tables and weekly grids, carries table columns across PDF pages, and flags OCR output for review. Layouts vary; extraction is best effort and does not guarantee every row or field. A cropped image cannot recover content outside its edges.

Excel `.xlsx` and legacy `.xls` files are decoded locally in Dart, including merged cells, formatted times, and saved formula values. Formulas and macros are never executed. Workbooks must be at most 10 MB, with at most 20 sheets, 2,000 rows and 50 columns per sheet, and 30,000 total cells. Compressed XLSX contents also have an expansion limit. Helpful column headers are **Day**, **Subject** or **Meal**, **Start**, **End**, **Room**, **Instructor**, and **Menu/Notes**. Meal grids can have days down the left and Breakfast/Lunch/Dinner across the top; absent meal times need correction.

Each import previews at most 200 routines. Matching title, kind, and times are checked against the existing plan and the selected batch. Covered weekdays are skipped, while missing weekdays are added using fresh IDs. Existing routines and check-offs are preserved. Original file bytes and paths are not saved, student identities in documents do not replace the workspace profile, and documents are not sent to AI Coach or another server. No OpenAI key or backend is needed for importing.

PDF and image extraction currently has a macOS native adapter. Excel decoding is portable across native Dart platforms, but mobile picking and imports still require device verification. Android/iOS native PDF and OCR adapters are future extension points; other platforms show an explicit message for those file types.

## AI-only progress judgments

Understanding, Practice, Consistency, and Outcomes are judged only by AI in both tracks. Current ratings cannot be entered with sliders, created from old check-ins, or awarded through a goal checkbox. Set a **target AI score** as an aspiration; this does not change your rating. **Overview** and **Goals** show only the latest judgment matching the current saved assessment evidence. New or deleted assessments make earlier judgments stale until you request a fresh review.

Complete Testing Lab assessments, then choose **Ask AI to judge progress** on Overview or **Review progress** on Goals. The selected AI connection reviews up to 12 recent, non-future assessment summaries: topic, level, question count, assessed marks, feedback, missing concepts, and recorded completion dates. It excludes your written answers, manual check-ins, routines, tasks, name, and goals. The AI must cite actual assessment IDs and explain its judgments. A numeric score needs evidence; insufficient evidence remains **Not assessed**, not zero.

Understanding and Practice reflect demonstrated answer quality. Consistency needs at least three distinct assessed dates within fourteen days before AI can judge participation patterns. Outcomes needs at least two assessments on different days with the same normalized topic, difficulty, and question count before AI can judge demonstrated learning growth. These eligibility checks do not assign scores; AI supplies the judgments. Outcomes describes assessed learning, without claiming verified employment experience or project credentials. Goal attainment is derived only from the current AI score meeting your chosen target. Older manual completion flags are retained in backups for compatibility and ignored by the new Goals page.

Reviews are explicit paid API actions using the configured server key. Successful retries reuse cached responses; failed local saves can retry without another AI call. Ratings and feedback save locally with their evidence references. An old judgment is never silently reused for changed evidence. AI feedback remains formative practice guidance and can be mistaken.

## Timed notifications

Open **Settings → Notifications and reminders → Enable timed reminders** and allow notifications in the macOS prompt. Choose **At the scheduled time**, or 5, 10 (default), 15, 30, or 60 minutes before. You can refresh the schedule, send a test notification, or disable it. Permission is not requested merely by opening the app.

Classes and meals use their weekly day/time. Daily tasks need an optional time set to receive a dated reminder. Completed or deleted tasks are removed from the pending schedule; edits update existing reminder IDs. If a task’s advance notice already passed, its reminder uses the actual task time. Weekly reminders repeat until edited or deleted. The app reconciles the schedule after saved changes and on resume. It uses local calendar times, including weekly reminders crossing midnight.

macOS schedules delivery even after the app closes, using [local notification requests](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app). OS permission, Focus modes, and alert settings affect visibility. Only macOS notifications are implemented in this release. The current schedule is bounded to 64 requests, reserving dated tasks before weekly reminders; Settings shows a notice if items are deferred. Open the app as tasks finish to refresh remaining requests. Notification content stays on the device and does not use OpenAI. Goal deadlines remain date-only targets and do not currently schedule reminders.

## Local data and backups

`path_provider` locates the platform application-support directory, where the app saves `progress_v1.json`. The versioned JSON includes your name, check-ins, goals, manual benchmark profiles, selected target, weekly routines, date-specific routine check-offs, completed Testing Lab results, researched paths, project evidence, daily tasks, AI judgments, and reminder preferences. Schema 6 reads schema 1, 2, 3, 4, and 5 files and backups, supplying empty collections for features absent from older versions. Existing progress, goals, profiles, routines, check-offs, and completed assessments are preserved. The filename stays `progress_v1.json` so existing installations keep their data. Saves write a temporary file and replace the previous complete file. A failed save retains the last committed state; unreadable saved data produces an error instead of being overwritten with sample data.

**Export backup** displays JSON and lets you copy it. Save that text yourself as a `.json` file. **Restore backup** accepts pasted JSON, validates it, and asks before replacing the current workspace. Backups are plain text and include your notes and profile information.

Example profiles are fictional. Custom benchmarks are manual estimates using scores someone has shared with you and the same rubric. Authentication, verified peer profiles, cloud synchronization, and cross-device sharing are future work. Public web research supplies sourced professional context rather than authenticated student discovery. The app supports one local workspace and one selected target across its two tracks; the target is shown only when its track is selected.

## Structure and extension

The feature-first organization is inspired by [Ranjit-Dit/Ecommerce-App](https://github.com/Ranjit-Dit/Ecommerce-App/), which separates `lib/common` and `lib/features` and organizes its homepage into `cubit`, `model`, `resources`, and `ui`. Progress Meter retains the common/features convention with explicit domain, data, and presentation layers. No ecommerce application code was copied.

State uses Flutter's SDK `ChangeNotifier` and `ListenableBuilder`. A repository interface isolates local storage so a backend can be introduced without embedding network operations in the screens. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the current data flow and extension points.

Tests cover score validation and calculation, historical ordering, serialization, persistence and corrupted data, controller save behavior, core interaction flows, safe areas, responsive layouts, keyboard access, and chart rendering/accessibility. The analyzer reports no issues; all 233 Flutter tests and 53 backend tests pass. Native macOS debug and release apps were built; the current 1.8.0 release and its signature were verified. The UI was verified while running on macOS. The standard Flutter macOS build encountered an environment-specific Xcode workspace-loader failure, addressed by the direct-Xcode fallback above. The iOS 1.8.0 Release app passed strict code-signature verification and was installed and launched on the connected iPhone. Individual iPhone features and Android remain unverified.

## Next features

1. Add identity and an API-backed repository, explicit profile-sharing controls, and real peer profiles.
2. Define evidence-based rubrics and attach supporting work, then add grade, course, project, and portfolio integrations.
3. Introduce subjects, courses, skill areas, and education/career requirements with explicit units and comparable rubric versions.
4. Split the presentation workspace into focused screens as features grow, then verify mobile navigation, platform persistence, accessibility, and release builds.
