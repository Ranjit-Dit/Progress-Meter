"""Optional LLM layer. The AI service works fully WITHOUT any API key (dictionary
fallback). If OPENAI_API_KEY is set (any OpenAI-compatible gateway via OPENAI_BASE_URL),
the LLM enhances extraction. On ANY failure we return None -> caller falls back."""
import json
import os
import urllib.request

SYSTEM = "You are a strict JSON extractor. Return ONLY valid JSON, no prose, no code fences."


def llm_json(prompt: str):
    key = os.getenv("OPENAI_API_KEY")
    if not key:
        return None
    base = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    body = {
        "model": os.getenv("LLM_MODEL", "gpt-4o-mini"),
        "temperature": 0,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": prompt},
        ],
    }
    req = urllib.request.Request(
        base + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            out = json.loads(r.read().decode())
        content = out["choices"][0]["message"]["content"]
        data = json.loads(content)
        return data if isinstance(data, dict) else None
    except Exception:
        return None
