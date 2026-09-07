import hashlib
import json
import logging
from google import genai
from google.genai import types, errors
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from config import (
    GEMINI_API_KEY, LLM_MODEL,
    MAX_RETRY_ATTEMPTS, RETRY_MIN_WAIT, RETRY_MAX_WAIT
)

logger = logging.getLogger("progress_matching")
client = genai.Client(api_key=GEMINI_API_KEY)

SYSTEM_PROMPT = (
    "You are an expert career and skill advisor for the Progress platform. "
    "Only use the student/opportunity data provided - never invent skills, scores, "
    "or facts about the student. When recommending external resources (courses, "
    "certifications, projects), be specific and concrete - prefer well-known, "
    "real platforms and certification names over vague descriptions. "
    "Always reply with valid JSON only, matching the exact schema requested."
)

_llm_cache: dict = {}


def _cache_key(system_prompt: str, user_prompt: str, temperature: float) -> str:
    raw = f"{system_prompt}||{user_prompt}||{temperature}"
    return hashlib.sha256(raw.encode()).hexdigest()


@retry(
    stop=stop_after_attempt(MAX_RETRY_ATTEMPTS),
    wait=wait_exponential(multiplier=1, min=RETRY_MIN_WAIT, max=RETRY_MAX_WAIT),
    retry=retry_if_exception_type(errors.ServerError),
    reraise=True
)
def _generate(user_prompt: str, system_prompt: str, temperature: float) -> str:
    response = client.models.generate_content(
        model=LLM_MODEL,
        contents=user_prompt,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            response_mime_type="application/json",
            temperature=temperature
        )
    )
    return response.text


def call_llm(user_prompt: str, system_prompt: str = SYSTEM_PROMPT, temperature: float = 0.3, use_cache: bool = True) -> dict:
    """Send a prompt to Gemini and return the parsed JSON response.
    Auto-retries on transient server errors (e.g. 503 UNAVAILABLE).
    Caches identical calls in memory to save API quota.
    """
    key = _cache_key(system_prompt, user_prompt, temperature)

    if use_cache and key in _llm_cache:
        logger.info("LLM cache hit - skipped API call")
        return _llm_cache[key]

    raw_text = _generate(user_prompt, system_prompt, temperature)
    result = json.loads(raw_text)

    if use_cache:
        _llm_cache[key] = result

    return result
