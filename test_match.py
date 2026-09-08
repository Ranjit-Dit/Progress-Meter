from internship_intelligence.compatibility import compatibility
from internship_intelligence.ranking import rank

STU = {"sk_linux": 1.0, "sk_git": 0.4}
OPP = {
    "opportunity_id": 7,
    "title": "DevOps Intern",
    "required_skills": [
        {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 1.0},
        {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.8},
        {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
    ],
    "eligibility": {"min_cgpa": 7.0},
}


def test_score_and_buckets():
    r = compatibility(STU, OPP, {"cgpa": 8.1, "degree": "B.Tech"})
    assert r["compatibility_score"] == 50.0          # earned 1.5 / possible 3
    assert r["eligible"] is True
    assert len(r["matched"]) == 1 and r["matched"][0]["skill_id"] == "sk_linux"
    assert len(r["partial"]) == 1 and r["partial"][0]["credit"] == 0.5
    assert len(r["missing"]) == 1 and r["missing"][0]["skill_id"] == "sk_docker"
    assert r["explanation"]["earned"] == 1.5 and r["explanation"]["possible"] == 3


def test_eligibility_fail_keeps_score():
    r = compatibility(STU, OPP, {"cgpa": 6.0})
    assert r["eligible"] is False
    assert r["compatibility_score"] == 50.0
    assert any(c["rule"].startswith("cgpa") and not c["passed"] for c in r["eligibility_checks"])


def test_full_and_empty():
    full = compatibility({"sk_linux": 1.0, "sk_git": 1.0, "sk_docker": 1.0}, OPP, None)
    assert full["compatibility_score"] == 100.0
    empty = compatibility({}, OPP, None)
    assert empty["compatibility_score"] == 0.0


def test_ranking_order():
    a = compatibility({"sk_linux": 1.0}, OPP, None)
    b = compatibility({"sk_linux": 1.0, "sk_git": 1.0, "sk_docker": 1.0}, OPP, None)
    out = rank([a, b])
    assert out[0]["compatibility_score"] == 100.0
