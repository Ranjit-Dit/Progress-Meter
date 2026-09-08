"""The one scoring formula used by BOTH readiness and compatibility:
credit = min(1, proficiency / min_proficiency), 0 if skill absent
score  = 100 * sum(weight * credit) / sum(weight)"""


def credit(proficiency, min_proficiency) -> float:
    if proficiency is None or proficiency <= 0:
        return 0.0
    mp = max(float(min_proficiency or 0), 0.05)
    return round(min(1.0, float(proficiency) / mp), 4)


def status_of(c: float) -> str:
    if c >= 1.0:
        return "matched"
    return "partial" if c > 0 else "missing"


def compute_score(rows):
    earned = sum(r["weight"] * r["credit"] for r in rows)
    possible = sum(r["weight"] for r in rows)
    score = round(100.0 * earned / possible, 1) if possible else 0.0
    return score, round(earned, 4), round(possible, 4)
