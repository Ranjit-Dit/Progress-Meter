from utils.helpers import call_llm
from prompts.templates import build_explain_prompt


def generate_match_explanation(match_result: dict) -> dict:
    """
    Problem 3: Explainable Match Results
    """
    prompt = build_explain_prompt(match_result)
    return call_llm(prompt)
