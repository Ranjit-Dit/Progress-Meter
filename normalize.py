"""Normalize any spelling of a skill to ONE canonical taxonomy skill.
Pipeline: clean -> exact -> alias -> fuzzy(>=88) -> semantic(>=0.82, optional) -> unmapped."""
import re

from rapidfuzz import fuzz, process

from skill_intelligence.taxonomy import alias_index, fuzzy_corpus, get_name, name_index

FUZZY_THRESHOLD = 88.0
SEMANTIC_THRESHOLD = 0.82

_embedder_state = {}
_corpus_emb = None


def _embedder():
    if "model" not in _embedder_state:
        try:
            from sentence_transformers import SentenceTransformer  # optional dep
            _embedder_state["model"] = SentenceTransformer("all-MiniLM-L6-v2")
        except Exception:
            _embedder_state["model"] = None
    return _embedder_state["model"]


def clean(term: str) -> str:
    t = term.strip().lower()
    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"\bv?\d+(\.\d+)+\b$", "", t).strip()  # strip trailing versions: "terraform 1.5"
    t = t.strip(" .,;:|/-_")
    return t


def _hit(term, skill_id, method, score):
    return {"input": term, "skill_id": skill_id, "name": get_name(skill_id),
            "method": method, "score": round(float(score), 3)}


def _unmapped(term):
    return {"input": term, "skill_id": None, "name": None, "method": "unmapped", "score": 0.0}


def _semantic(t):
    global _corpus_emb
    model = _embedder()
    if model is None:
        return None
    import numpy as np
    keys = list(fuzzy_corpus().keys())
    if _corpus_emb is None or _corpus_emb[0] != keys:
        _corpus_emb = (keys, model.encode(keys, normalize_embeddings=True))
    vec = model.encode([t], normalize_embeddings=True)[0]
    sims = _corpus_emb[1] @ vec
    i = int(np.argmax(sims))
    if float(sims[i]) >= SEMANTIC_THRESHOLD:
        return fuzzy_corpus()[keys[i]], float(sims[i])
    return None


def normalize(term: str) -> dict:
    t = clean(term)
    if not t:
        return _unmapped(term)
    if t in name_index():
        return _hit(term, name_index()[t], "exact", 1.0)
    if t in alias_index():
        return _hit(term, alias_index()[t], "alias", 1.0)
    best = process.extractOne(t, list(fuzzy_corpus().keys()), scorer=fuzz.token_set_ratio)
    if best and best[1] >= FUZZY_THRESHOLD:
        return _hit(term, fuzzy_corpus()[best[0]], "fuzzy", best[1] / 100.0)
    sem = _semantic(t)
    if sem:
        return _hit(term, sem[0], "semantic", sem[1])
    return _unmapped(term)


def normalize_many(terms):
    return [normalize(str(t)) for t in terms]
