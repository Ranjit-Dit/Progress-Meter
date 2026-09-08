"""Explainable compatibility result: score + eligibility + matched/partial/missing
buckets + formula breakdown. No score is ever returned without its explanation."""
from internship_intelligence.eligibility.eligibility import check as eligibility_check
from internship_intelligence.matching.matcher import match

FORMULA = "score = 100 * sum(weight x credit) / sum(weight)"
CREDIT_RULE = "credit = min(1, proficiency / min_proficiency); 0 if skill absent"


def compatibility(student_skills: dict, opportunity: dict, student_meta: dict = None) -> dict:
    res = match(student_skills, opportunity.get("required_skills", []))
    elig = eligibility_check(student_meta, opportunity.get("eligibility"))
    buckets = {"matched": [], "partial": [], "missing": []}
    for row in res["rows"]:
        buckets[row["status"]].append(row)
    return {
        "opportunity_id": opportunity.get("opportunity_id"),
        "title": opportunity.get("title"),
        "compatibility_score": res["score"],
        "eligible": elig["eligible"],
        "eligibility_checks": elig["checks"],
        "matched": buckets["matched"],
        "partial": buckets["partial"],
        "missing": buckets["missing"],
        "explanation": {
            "formula": FORMULA,
            "credit_rule": CREDIT_RULE,
            "earned": res["earned"],
            "possible": res["possible"],
        },
    }
