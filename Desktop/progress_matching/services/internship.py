from typing import Dict, List
from services.compatibility import calculate_compatibility
from utils.helpers import call_llm
from prompts.templates import build_internship_prompt


def recommend_internships(student: Dict, opportunities: List[Dict], top_n: int = 5) -> Dict:
    """
    Problem 8: Internship Recommendations
    Step 1: Score every opportunity deterministically (no AI, no cost)
    Step 2: Send only the top N to the LLM for ranking + explanations
    """
    scored = []
    for opp in opportunities:
        result = calculate_compatibility(student, opp)
        scored.append({
            "opportunity_id": opp.get("opportunity_id"),
            "title": opp.get("title"),
            "compatibility_score": result["compatibility_score"],
            "matched": result["matched"],
            "partial": result["partial"],
            "missing": result["missing"]
        })

    scored.sort(key=lambda x: x["compatibility_score"], reverse=True)
    top_scored = scored[:top_n]

    prompt = build_internship_prompt(student, top_scored)
    return call_llm(prompt)
