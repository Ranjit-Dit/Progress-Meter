"""Student profile vs internship requirement comparison (delegates to the shared
gap engine so readiness and compatibility can never drift apart)."""
from skill_intelligence.skill_gap.gap import compare


def match(student_skills: dict, required_skills: list) -> dict:
    return compare(student_skills, required_skills or [])
