from typing import Dict
from utils.helpers import call_llm
from prompts.templates import build_career_prompt


def recommend_careers(student: Dict) -> Dict:
    """
    Problem 5: Career Recommendations
    """
    prompt = build_career_prompt(student)
    return call_llm(prompt)
