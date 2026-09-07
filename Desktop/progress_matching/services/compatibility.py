from typing import Dict
from services.embeddings import semantic_skill_match
from config import DEFAULT_WEIGHTS, VERIFICATION_SCORES, SEMANTIC_THRESHOLD


def _find_student_skill(student_skills, skill_name):
    for s in student_skills:
        if s["name"].strip().lower() == skill_name.strip().lower():
            return s
    return None


def _score_single_skill(student_skills, required_skill):
    name = required_skill["name"]
    min_prof = required_skill.get("min_proficiency", 0)

    match = _find_student_skill(student_skills, name)
    if match:
        if match["proficiency"] >= min_prof:
            return 1.0, "matched", match
        ratio = match["proficiency"] / min_prof if min_prof else 1.0
        return round(0.4 + 0.3 * ratio, 4), "partial", match

    # No exact name match - try semantic similarity against student's skills
    best_score = 0.0
    best_match = None
    for s in student_skills:
        result = semantic_skill_match(s["name"], name)
        if result["similarity_score"] > best_score:
            best_score = result["similarity_score"]
            best_match = s

    if best_score >= SEMANTIC_THRESHOLD and best_match:
        ratio = best_match["proficiency"] / min_prof if min_prof else 1.0
        return round(0.6 + 0.4 * min(ratio, 1.0), 4), "partial", best_match

    return 0.0, "missing", None


def calculate_compatibility(student: Dict, opportunity: Dict, weights: Dict = None) -> Dict:
    """
    Problem 2: Student–Opportunity Compatibility
    """
    weights = weights or DEFAULT_WEIGHTS
    student_skills = student.get("skills", [])
    required_skills = opportunity.get("required_skills", [])

    matched, partial, missing = [], [], []
    weighted_scores = []
    total_weight = 0.0
    verification_scores = []

    for req in required_skills:
        w = req.get("weight", 1.0 / max(len(required_skills), 1))
        score, status, matched_skill = _score_single_skill(student_skills, req)

        weighted_scores.append(score * w)
        total_weight += w

        if status == "matched":
            matched.append(req["name"])
            verification_scores.append(VERIFICATION_SCORES.get(matched_skill.get("verification_level"), 0.2))
        elif status == "partial":
            partial.append(req["name"])
            if matched_skill:
                verification_scores.append(VERIFICATION_SCORES.get(matched_skill.get("verification_level"), 0.2))
        else:
            missing.append(req["name"])

    skill_fit = sum(weighted_scores) / total_weight if total_weight else 0.0

    # Eligibility fit
    student_elig = student.get("eligibility", {})
    opp_elig = opportunity.get("eligibility", {})
    eligibility_fit = 1.0
    if opp_elig.get("locations") and student_elig.get("location"):
        eligibility_fit = 1.0 if student_elig["location"] in opp_elig["locations"] else 0.5
    if opp_elig.get("min_degree") and student_elig.get("degree"):
        if student_elig["degree"] != opp_elig["min_degree"]:
            eligibility_fit = min(eligibility_fit, 0.7)

    # Goal alignment
    student_roles = {g["role_name"] for g in student.get("career_goals", [])}
    opp_roles = set(opportunity.get("career_roles", []))
    goal_alignment = 1.0 if student_roles & opp_roles else (0.5 if student_roles or opp_roles else 0.0)

    # Verification boost
    verification_boost = sum(verification_scores) / len(verification_scores) if verification_scores else 0.0

    compatibility_score = round(100 * (
        weights["skill_fit"] * skill_fit +
        weights["eligibility_fit"] * eligibility_fit +
        weights["goal_alignment"] * goal_alignment +
        weights["verification_boost"] * verification_boost
    ), 2)

    return {
        "compatibility_score": compatibility_score,
        "factors": {
            "skill_fit": round(skill_fit, 4),
            "eligibility_fit": round(eligibility_fit, 4),
            "goal_alignment": round(goal_alignment, 4),
            "verification_boost": round(verification_boost, 4)
        },
        "matched": matched,
        "partial": partial,
        "missing": missing,
        "priority_gaps": missing + partial
    }
