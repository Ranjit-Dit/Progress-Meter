from internship_intelligence.extraction import parse_jd
from skill_intelligence.extraction import parse_resume

RESUME = """EDUCATION
B.Tech Computer Science, 2026 batch, CGPA: 8.1
SKILLS
ReactJS, node.js, Python, SQL
EXPERIENCE
SDE Intern, XYZ - Jun 2024 - Aug 2024
PROJECTS
Campus Portal - a react based portal
CERTIFICATIONS
AWS Cloud Practitioner (2025)
"""

JD = """DevOps Intern
Must have Docker and Linux. Good to have Terraform.
Requires 6+ months of experience.
Eligibility: B.Tech CSE 2026 batch, CGPA 7.0+
"""


def test_resume_dictionary_layer():
    r = parse_resume(RESUME, use_llm=False)
    ids = {s["skill_id"] for s in r["skills"]}
    assert {"sk_react", "sk_node", "sk_python", "sk_sql", "sk_aws"} <= ids
    assert "sk_js" not in ids  # 'node.js' must not double-match the bare 'js' alias
    assert r["extraction_source"] == "dictionary"
    assert r["experience"]["total_months"] == 3
    assert r["education"]["degree"] == "B.Tech"
    assert r["education"]["cgpa"] == 8.1
    assert r["education"]["grad_year"] == 2026
    assert any("AWS Cloud Practitioner" in c for c in r["certifications"])
    assert any("Campus Portal" in p for p in r["projects"])


def test_jd_weights_and_eligibility():
    r = parse_jd(JD, use_llm=False)
    by_id = {s["skill_id"]: s for s in r["required_skills"]}
    assert by_id["sk_docker"]["weight"] == 1.0
    assert by_id["sk_linux"]["weight"] == 1.0
    assert by_id["sk_terraform"]["weight"] == 0.5
    assert r["experience"]["min_months"] == 6
    e = r["eligibility"]
    assert "B.Tech" in e["degrees"]
    assert "CSE" in e["branches"]
    assert e["min_cgpa"] == 7.0
    assert 2026 in e["grad_years"]
