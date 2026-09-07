from typing import List, Dict
from utils.helpers import call_llm
from prompts.templates import build_skill_gap_prompt


def analyze_skill_gap(student_skills: List[Dict], target_role: str, required_skills: List[Dict]) -> Dict:
    """
    Problem 4: Skill-Gap Explanation
    """
    prompt = build_skill_gap_prompt(student_skills, target_role, required_skills)
    return call_llm(prompt)
