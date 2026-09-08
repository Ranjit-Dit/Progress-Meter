from internship_intelligence.recommendation import recommend
from skill_intelligence.priority_gap import prioritize

GAPS = [{"skill_id": "sk_docker", "weight": 1.0},
        {"skill_id": "sk_terraform", "weight": 0.5}]
OPPS = [{"opportunity_id": 9, "title": "Cloud Ops Intern",
         "required_skills": [{"skill_id": "sk_docker"}, {"skill_id": "sk_terraform"}]}]


def test_recommend_covers_and_reasons():
    r = recommend(GAPS, limit=3, opportunities=OPPS)
    assert r["courses"][0]["score"] >= 1.0
    assert "sk_docker" in r["courses"][0]["covers"]
    assert "Docker" in r["courses"][0]["reason"]
    assert r["internships"][0]["score"] == 1.5
    assert r["roadmap"][0]["skill_id"] == "sk_docker"
    types = [c["type"] for c in r["roadmap"][0]["chain"]]
    assert types == ["course", "project", "assessment"]


def test_prioritize_order():
    rows = [
        {"skill_id": "sk_terraform", "name": "Terraform", "weight": 0.5, "credit": 0.0,
         "status": "missing", "your_proficiency": 0.0, "required": 0.3},
        {"skill_id": "sk_docker", "name": "Docker", "weight": 1.0, "credit": 0.4,
         "status": "partial", "your_proficiency": 0.2, "required": 0.5},
        {"skill_id": "sk_linux", "name": "Linux", "weight": 1.0, "credit": 1.0,
         "status": "matched", "your_proficiency": 1.0, "required": 0.6},
    ]
    p = prioritize(rows)
    assert [g["skill_id"] for g in p] == ["sk_docker", "sk_terraform"]
    assert p[0]["severity"] == "partial" and p[1]["severity"] == "absent"
