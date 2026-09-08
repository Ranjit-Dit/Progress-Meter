# Progress — AI Intelligence Microservice (owner: AI module)

Stateless FastAPI service. No DB access. The main backend hydrates payloads from
PostgreSQL and calls these endpoints; the LLM is optional (works 100% without a key).

## Setup
```bash
cd ai-intelligence
python3 -m venv .venv && source .venv/bin/activate   # optional but recommended
pip install -r requirements.txt
python3 -m pytest tests/ -q                          # must show 17 passed
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Interactive docs: http://localhost:8000/docs

## Optional LLM enhancement
```bash
export OPENAI_API_KEY=sk-...          # any OpenAI-compatible gateway:
export OPENAI_BASE_URL=https://...    # (default https://api.openai.com/v1)
export LLM_MODEL=gpt-4o-mini
```
Without a key every endpoint still works (dictionary layer), responses carry
`"extraction_source": "dictionary"`.

## Endpoints
| Method & path | Purpose |
|---|---|
| GET  /ai/skills | taxonomy (canonical names, categories, aliases) |
| POST /ai/skills/normalize | any spelling -> ONE canonical skill |
| POST /ai/resume/extract | resume text -> skills/exp/certs/projects/education |
| POST /ai/opportunity/extract | JD text -> weighted required skills + eligibility |
| POST /ai/match | explainable compatibility score (matched/partial/missing) |
| POST /ai/matches/batch | rank many opportunities for one student |
| POST /ai/skill-gap | role readiness % + priority gaps |
| POST /ai/recommendations | gap -> courses/projects/assessments/internships + roadmap |

See INTEGRATION.md for the contracts the backend / UI / DB / security owners need.
