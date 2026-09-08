"""Career-role readiness: same formula as compatibility, applied to a target role."""
from skill_intelligence.skill_gap.gap import compare


def readiness(student_skills: dict, role_requirements: list) -> dict:
    res = compare(student_skills, role_requirements)
    gaps = [r for r in res["rows"] if r["credit"] < 1.0]
    return {
        "readiness": res["score"],
        "rows": res["rows"],
        "gaps": gaps,
        "explanation": {
            "formula": "readiness = 100 * sum(weight x credit) / sum(weight)",
            "credit_rule": "credit = min(1, proficiency / min_proficiency); 0 if skill absent",
            "earned": res["earned"],
            "possible": res["possible"],
        },
    }
