from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_skills_endpoint():
    r = client.get("/ai/skills")
    assert r.status_code == 200 and len(r.json()) >= 30


def test_normalize_endpoint():
    r = client.post("/ai/skills/normalize", json={"terms": ["ReactJS", "k8s", "zzzunknown"]})
    out = r.json()["results"]
    assert out[0]["skill_id"] == "sk_react"
    assert out[1]["skill_id"] == "sk_kubernetes"
    assert out[2]["skill_id"] is None


def test_match_endpoint():
    body = {
        "student": {"student_id": 1, "meta": {"cgpa": 8.1},
                    "skills": [{"skill_id": "sk_linux", "proficiency": 1.0},
                               {"skill_id": "sk_git", "proficiency": 0.4}]},
        "opportunity": {"opportunity_id": 7, "title": "DevOps Intern",
                        "required_skills": [
                            {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 1.0},
                            {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.8},
                            {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5}],
                        "eligibility": {"min_cgpa": 7.0}},
    }
    r = client.post("/ai/match", json=body)
    assert r.status_code == 200
    j = r.json()
    assert j["compatibility_score"] == 50.0 and j["eligible"] is True
    assert "formula" in j["explanation"]


def test_resume_and_jd_endpoints():
    r = client.post("/ai/resume/extract",
                    json={"resume_text": "SKILLS\nReactJS, Docker\n", "use_llm": False})
    ids = {s["skill_id"] for s in r.json()["skills"]}
    assert {"sk_react", "sk_docker"} <= ids
    j = client.post("/ai/opportunity/extract",
                    json={"jd_text": "Must have Docker.\n", "use_llm": False}).json()
    assert j["required_skills"][0]["skill_id"] == "sk_docker"


def test_skill_gap_and_recommendations():
    r = client.post("/ai/skill-gap", json={
        "student": {"skills": [{"skill_id": "sk_linux", "proficiency": 1.0}]},
        "role_requirements": [{"skill_id": "sk_linux", "weight": 1.0},
                              {"skill_id": "sk_docker", "weight": 1.0}]})
    j = r.json()
    assert j["readiness"] == 50.0
    assert j["priority_gaps"][0]["skill_id"] == "sk_docker"
    rec = client.post("/ai/recommendations", json={
        "gaps": [{"skill_id": "sk_docker", "weight": 1.0}]}).json()
    assert rec["roadmap"][0]["chain"][0]["type"] == "course"
