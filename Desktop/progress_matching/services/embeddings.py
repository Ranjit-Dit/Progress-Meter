import logging
from google import genai
from google.genai import errors
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import numpy as np
from typing import List, Dict
from config import (
    GEMINI_API_KEY, EMBEDDING_MODEL, SEMANTIC_THRESHOLD,
    MAX_RETRY_ATTEMPTS, RETRY_MIN_WAIT, RETRY_MAX_WAIT
)

logger = logging.getLogger("progress_matching")
client = genai.Client(api_key=GEMINI_API_KEY)

_embedding_cache: dict = {}


@retry(
    stop=stop_after_attempt(MAX_RETRY_ATTEMPTS),
    wait=wait_exponential(multiplier=1, min=RETRY_MIN_WAIT, max=RETRY_MAX_WAIT),
    retry=retry_if_exception_type(errors.ServerError),
    reraise=True
)
def _embed_texts(texts: List[str]) -> List[List[float]]:
    result = client.models.embed_content(model=EMBEDDING_MODEL, contents=texts)
    return [list(e.values) for e in result.embeddings]


def get_embedding(text: str) -> List[float]:
    """Get embedding vector for a single text. Cached + auto-retried."""
    if not text or not text.strip():
        return []
    key = text.strip().lower()
    if key in _embedding_cache:
        return _embedding_cache[key]
    embedding = _embed_texts([text.strip()])[0]
    _embedding_cache[key] = embedding
    return embedding


def get_embeddings_batch(texts: List[str]) -> List[List[float]]:
    """Get embeddings for multiple texts, reusing the cache and only calling the API for new ones."""
    clean_texts = [t.strip() for t in texts if t and t.strip()]
    if not clean_texts:
        return []

    to_fetch = [t for t in clean_texts if t.lower() not in _embedding_cache]
    if to_fetch:
        fresh = _embed_texts(to_fetch)
        for t, emb in zip(to_fetch, fresh):
            _embedding_cache[t.lower()] = emb
        logger.info(f"Embedded {len(to_fetch)} new skill(s), {len(clean_texts) - len(to_fetch)} from cache")

    return [_embedding_cache[t.lower()] for t in clean_texts]


def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    if not vec1 or not vec2:
        return 0.0
    a, b = np.array(vec1), np.array(vec2)
    norm_a, norm_b = np.linalg.norm(a), np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


def semantic_skill_match(student_skill: str, required_skill: str) -> Dict:
    """
    Problem 1: Semantic Skill Matching
    """
    emb1 = get_embedding(student_skill)
    emb2 = get_embedding(required_skill)
    score = cosine_similarity(emb1, emb2)
    return {
        "student_skill": student_skill,
        "required_skill": required_skill,
        "similarity_score": round(score, 4),
        "is_semantic_match": score >= SEMANTIC_THRESHOLD,
        "threshold_used": SEMANTIC_THRESHOLD
    }


def batch_semantic_match(student_skills: List[str], required_skills: List[str]) -> List[Dict]:
    results = []
    student_embeddings = dict(zip(student_skills, get_embeddings_batch(student_skills)))

    for req in required_skills:
        req_emb = get_embedding(req)
        best_score = 0.0
        best_skill = None
        for skill, emb in student_embeddings.items():
            score = cosine_similarity(emb, req_emb)
            if score > best_score:
                best_score = score
                best_skill = skill
        results.append({
            "required_skill": req,
            "best_student_skill": best_skill,
            "similarity_score": round(best_score, 4),
            "is_semantic_match": best_score >= SEMANTIC_THRESHOLD
        })
    return results
