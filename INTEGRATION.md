# Integration Contracts — who builds what against the AI service

## 1) DB owner (PostgreSQL) — tables the backend must fill/read around AI calls
```sql
skills(id text pk, name text unique, category text, aliases jsonb)          -- seed from skill_intelligence/taxonomy/skills.json
student_skills(student_id fk, skill_id fk, proficiency real check (proficiency between 0 and 1),
               source text,          -- 'resume' | 'assessment' | 'manual'
               verification text,    -- 'SELF_DECLARED' | 'ASSESSMENT_VERIFIED' | ... (portfolio ladder)
               primary key (student_id, skill_id))
opportunity_skills(opportunity_id fk, skill_id fk, weight real, min_proficiency real)
career_role_skills(role_id fk, skill_id fk, weight real, min_proficiency real)
course_skills(course_id fk, skill_id fk)
project_skills(project_id fk, skill_id fk)
documents(id pk, owner_id fk, doc_type text, raw_payload jsonb, created_at timestamptz)  -- store extract results verbatim
students(id pk, degree text, branch text, cgpa real, grad_year int, location text)      -- feeds "student_meta"
```
Rules: proficiency is ALWAYS 0..1 (levels: beginner .25 / intermediate .5 / good .75 / expert 1).
weight: 1.0 must-have, 0.5 nice-to-have. Resume-extracted rows start at verification='SELF_DECLARED'.

## 2) Backend owner — wrapper endpoints (auth + persistence live HERE, not in AI service)
- `POST /api/resume/upload` (multipart) -> extract text (pypdf/python-docx) -> call AI `/ai/resume/extract`
  -> save `documents.raw_payload` + `student_skills(source='resume', verification='SELF_DECLARED')`
  -> return the extract so UI can show a confirm/edit screen.
- `POST /api/student/resume/confirm` -> apply student's edits to student_skills.
- `POST /api/opportunities` -> call AI `/ai/opportunity/extract` -> save opportunity + opportunity_skills + eligibility jsonb.
- `GET  /api/matches` -> build student vector from student_skills + meta; open opportunities from
  opportunity_skills; call AI `/ai/matches/batch`; return ranked list.
- `POST /api/matches/{id}` -> single `/ai/match` (explainable card).
- `GET  /api/recommendations` -> gaps from latest `/ai/skill-gap` (or top match's missing list)
  -> call AI `/ai/recommendations`.
AI service is called server-to-server only; never expose it publicly without the security owner's rate limits.

## 3) UI owner — screens and the exact JSON fields to render
- Resume upload screen: show `skills[]` chips (name + method), `unmapped_terms[]` as "not in taxonomy - review",
  education/experience/certs preview; confirm button hits backend confirm endpoint.
- Opportunity form: paste JD -> preview `required_skills[]` chips with weight badge (must/nice) + eligibility summary.
- Match card: `compatibility_score` ring; `matched[]` as checkmarks, `partial[]` as warning, `missing[]` as red;
  tooltip/accordion shows `explanation.formula`, `earned/possible`, per-row credit. NEVER show a bare score.
- Opportunity list: score badge from `/api/matches` (already ranked).
- Development path: `roadmap[]` (per gap: course -> project -> assessment chain) + top-3 `courses/projects/internships`
  with their `reason` strings.
- Skill picker/autocomplete: `GET /ai/skills` (via backend proxy).

## 4) Security owner — checklist touching this service
- CORS in app/main.py is `*` for dev ONLY - replace with the web app origin before staging.
- Add rate limiting + auth (JWT verify) at the MAIN BACKEND; keep AI service internal (network-private).
- Extract endpoints accept raw text: enforce max body size (e.g. 1 MB) at backend proxy.
- documents.raw_payload may contain PII - apply the project's document access-control rules.
- LLM key lives in secret manager (env var only); service logs must not print resume text.

## 5) Frozen rules (do not change without team sync)
- Score formula: `100 * sum(weight x credit) / sum(weight)`, `credit = min(1, proficiency/min_proficiency)`.
- Priority gaps ordered by recoverable points `weight x (1 - credit)`.
- Unmapped terms are NEVER scored.
- Every score response includes its explanation block.
- AI service stays stateless (no DB, no files written at runtime).
