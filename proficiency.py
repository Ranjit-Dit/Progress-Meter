"""Proficiency levels <-> 0..1 scores. Assessment results overwrite resume hints later."""
LEVELS = {"beginner": 0.25, "intermediate": 0.5, "good": 0.75, "expert": 1.0}


def level_to_score(level) -> float:
    if isinstance(level, (int, float)):
        return max(0.0, min(1.0, float(level)))
    return LEVELS.get(str(level).strip().lower(), 0.5)


def score_to_level(score: float) -> str:
    if score >= 0.875:
        return "expert"
    if score >= 0.625:
        return "good"
    if score >= 0.375:
        return "intermediate"
    return "beginner"
