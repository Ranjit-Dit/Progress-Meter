from typing import List, Dict
from utils.helpers import call_llm
from prompts.templates import build_learning_prompt


def recommend_learning(skill_gaps: List[Dict]) -> Dict:
    """
    Problem 6: Learning Recommendations
    """
    prompt = build_learning_prompt(skill_gaps)
    return call_llm(prompt)
