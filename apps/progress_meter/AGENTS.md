# Progress Meter product rules

- Understanding, Practice, Consistency, and Outcomes are judged only by AI from saved Testing Lab evidence. These labels apply to both Academic and Career tracks.
- Use `ProgressController.currentJudgment`, `judgedScore`, and `goalAchieved` for current score and goal surfaces. Never fall back to `ProgressEntry` self-ratings or manually completed goal flags.
- Missing or stale evidence means **Not assessed**, not zero. Current judgments must match the assessment fingerprint and cite valid assessment IDs. Consistency/outcomes must satisfy their evidence gates before receiving a score.
- Students may choose aspirational goal targets. They cannot enter their own current ratings or manually verify metric goals. Routine/task check-offs remain user-controlled and do not award progress scores.
- Preserve legacy records and backup compatibility; clearly label older self-ratings as an archive. New manual-scoring entry writes are disabled.
- Developer-owned AI keys stay in the backend environment. The user's requested personal-provider option may hold a user-entered key in app memory and send it only to that explicitly selected provider over HTTPS. Personal keys are session-only: never serialize them, include them in backups, log them, or bundle them. Never package `.env` or real student documents. AI progress reviews exclude written test answers, identity, routines, and tasks.
- Timed notifications use the platform scheduler and app-owned stable IDs. Request OS permission only through the explicit enable action. Reconcile edited/deleted/completed items and retain privacy/data on errors.
- Verify relevant domain/controller/widget behavior, narrow layouts, analyzer, backend tests, and the macOS build for changes affecting these boundaries.
