# Progress Matching Engine

AI-powered microservice for student-opportunity compatibility scoring and recommendations.

## Quick Start (Docker)
```bash
echo "GEMINI_API_KEY=your_key_here" > .env
docker compose up --build

#### 3. Test & Start the Server
```bash
uvicorn api:app --reload --port 8000
