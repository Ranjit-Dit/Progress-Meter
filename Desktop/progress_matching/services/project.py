from typing import List, Dict
from utils.helpers import call_llm
from prompts.templates import build_project_prompt


def recommend_projects(skill_gaps: List[Dict]) -> Dict:
    """
    Problem 7: Project Recommendations
    """
    prompt = build_project_prompt(skill_gaps)
    return call_llm(prompt)
