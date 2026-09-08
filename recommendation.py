"""Gap-driven recommendations: rank courses/projects/assessments/internships by the
total weight of priority gaps they cover, with human-readable reasons, plus a
per-gap roadmap chain (course -> project -> assessment)."""
import functools
import json
from pathlib import Path

from skill_intelligence.taxonomy import get_name

DATA = Path(__file__).parent / "learning_resources.json"
_CHAIN = (("course", "courses"), ("project", "projects"), ("assessment", "assessments"))


@functools.lru_cache(maxsize=1)
def _resources():
    with open(DATA, encoding="utf-8") as f:
        return json.load(f)


def recommend(gaps: list, types: list = None, limit: int = 3, opportunities: list = None) -> dict:
    types = types or ["course", "project", "internship", "assessment"]
    gap_w = {g["skill_id"]: float(g.get("weight", 1.0)) for g in gaps}
    names = {sid: get_name(sid) for sid in gap_w}
    res = _resources()
    out = {}

    def scored(covers):
        cov = sorted({s for s in covers if s in gap_w})
        return round(sum(gap_w[s] for s in cov), 4), cov

    for t, key in _CHAIN:
        if t not in types:
            continue
        items = []
        for it in res.get(key, []):
            sc, cov = scored(it.get("skill_ids", []))
            if sc > 0:
                items.append({**it, "covers": cov, "score": sc,
                              "reason": "Covers: " + ", ".join(names[s] for s in cov)})
        items.sort(key=lambda x: (-x["score"], x["id"]))
        out[key] = items[:limit]

    if "internship" in types:
        items = []
        for opp in opportunities or []:
            sc, cov = scored([r["skill_id"] for r in opp.get("required_skills", [])])
            if sc > 0:
                items.append({"opportunity_id": opp.get("opportunity_id"),
                              "title": opp.get("title"), "covers": cov, "score": sc,
                              "reason": "Covers: " + ", ".join(names[s] for s in cov)})
        items.sort(key=lambda x: (-x["score"], str(x["opportunity_id"])))
        out["internships"] = items[:limit]

    roadmap = []
    for g in sorted(gaps, key=lambda g: -float(g.get("weight", 1.0))):
        sid = g["skill_id"]
        chain = []
        for t, key in _CHAIN:
            hit = next((it for it in res.get(key, []) if sid in it.get("skill_ids", [])), None)
            if hit:
                chain.append({"type": t, "id": hit["id"], "title": hit["title"]})
        roadmap.append({"skill_id": sid, "name": names.get(sid, sid), "chain": chain})
    return {"roadmap": roadmap, **out}
