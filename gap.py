"""Core comparison: student skills vs required skills -> explainable rows + score."""
from skill_intelligence.scoring import compute_score, credit, status_of
from skill_intelligence.taxonomy import get_name


def compare(student_skills: dict, required: list) -> dict:
    rows = []
    for r in required:
        sid = r["skill_id"]
        prof = student_skills.get(sid)
        min_prof = float(r.get("min_proficiency", 0.5))
        weight = float(r.get("weight", 1.0))
        c = credit(prof, min_prof)
        rows.append({
            "skill_id": sid,
            "name": get_name(sid),
            "your_proficiency": prof if prof is not None else 0.0,
            "required": min_prof,
            "weight": weight,
            "credit": c,
            "status": status_of(c),
        })
    score, earned, possible = compute_score(rows)
    return {"rows": rows, "score": score, "earned": earned, "possible": possible}
