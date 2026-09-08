"""Job-description intelligence: required skills with weights, min experience, eligibility.
Dictionary layer always runs; LLM only enhances; failures fall back silently."""
import re

from shared.llm import llm_json
from skill_intelligence.extraction.resume_parser import (
    _BRANCH_ABBR, _BRANCH_PHRASES, _CGPA, _DEGREES, _GRAD, scan)
from skill_intelligence.normalization import normalize
from skill_intelligence.taxonomy import get_name

_NICE = re.compile(r"\b(good to have|nice to have|preferred|plus|bonus|familiar with)\b", re.I)
_MUST = re.compile(r"\b(must|required|mandatory)\b", re.I)
_STRONG = re.compile(r"\b(expert|strong|deep|proficient|advanced)\b", re.I)
_EXP = re.compile(r"(\d+)\s*\+?\s*(years|yrs|months)\b", re.I)

JD_PROMPT = """Extract structured data from this job/internship description. Return ONLY JSON with keys:
"required_skills": list of must-have skill names as written,
"nice_to_have": list of optional skill names as written,
"min_experience_months": integer,
"eligibility": object with "degrees" (list), "branches" (list), "min_cgpa" (number), "grad_years" (list of int), "location" (string) - use empty list/null when absent.
Job description:
{text}"""


def _scan_jd(text: str) -> dict:
    req = {}
    sentences = [(m.start(), m.end(), m.group(0)) for m in re.finditer(r"[^\n.;]+", text)]
    _, spans = scan(text)
    for start, _end, sid in spans:
        sent = next((s for s in sentences if s[0] <= start < s[1]), (0, 0, ""))[2]
        if _NICE.search(sent):
            w, mp = 0.5, 0.3
        elif _MUST.search(sent):
            w, mp = 1.0, 0.5
        else:
            w, mp = 1.0, 0.5
        if _STRONG.search(sent):
            mp = max(mp, 0.75)
        prev = req.get(sid)
        if prev is None or w > prev["weight"]:
            req[sid] = {"skill_id": sid, "raw": get_name(sid), "name": get_name(sid),
                        "weight": w, "min_proficiency": mp}
    return req


def _experience_min(text: str):
    m = _EXP.search(text)
    if not m:
        return 0
    n = int(m.group(1))
    return n * 12 if m.group(2).lower() in ("years", "yrs") else n


def _eligibility(text: str) -> dict:
    elig = {"degrees": [], "branches": [], "min_cgpa": None, "grad_years": [], "location": None}
    for rx, canon in _DEGREES:
        if re.search(rx, text, re.I):
            elig["degrees"].append(canon)
    for rx, canon in _BRANCH_PHRASES:
        if re.search(rx, text, re.I):
            elig["branches"].append(canon)
    for ab in _BRANCH_ABBR:
        if re.search(r"\b" + ab + r"\b", text):
            if ab not in elig["branches"]:
                elig["branches"].append(ab)
    c = _CGPA.search(text)
    if c:
        elig["min_cgpa"] = float(c.group(1))
    for g in _GRAD.finditer(text):
        y = int(g.group(1) or g.group(2))
        if y not in elig["grad_years"]:
            elig["grad_years"].append(y)
    return elig


def parse_jd(text: str, use_llm: bool = True) -> dict:
    req = _scan_jd(text)
    experience = {"min_months": _experience_min(text)}
    eligibility = _eligibility(text)
    unmapped, source = [], "dictionary"
    title = next((ln.strip() for ln in text.splitlines() if ln.strip()), None)

    if use_llm:
        data = llm_json(JD_PROMPT.format(text=text))
        if isinstance(data, dict):
            source = "llm+dictionary"
            for term in data.get("required_skills", []) or []:
                n = normalize(str(term))
                if n["skill_id"] and n["skill_id"] not in req:
                    req[n["skill_id"]] = {"skill_id": n["skill_id"], "raw": str(term),
                                          "name": n["name"], "weight": 1.0, "min_proficiency": 0.5}
                elif not n["skill_id"]:
                    unmapped.append(str(term))
            for term in data.get("nice_to_have", []) or []:
                n = normalize(str(term))
                if n["skill_id"] and n["skill_id"] not in req:
                    req[n["skill_id"]] = {"skill_id": n["skill_id"], "raw": str(term),
                                          "name": n["name"], "weight": 0.5, "min_proficiency": 0.3}
            lm = data.get("min_experience_months")
            if isinstance(lm, (int, float)) and lm > experience["min_months"]:
                experience["min_months"] = int(lm)
            le = data.get("eligibility") or {}
            if isinstance(le, dict):
                for d in le.get("degrees", []) or []:
                    if d not in eligibility["degrees"]:
                        eligibility["degrees"].append(str(d))
                for b in le.get("branches", []) or []:
                    if b not in eligibility["branches"]:
                        eligibility["branches"].append(str(b))
                if eligibility["min_cgpa"] is None and isinstance(le.get("min_cgpa"), (int, float)):
                    eligibility["min_cgpa"] = le["min_cgpa"]
                for y in le.get("grad_years", []) or []:
                    if isinstance(y, int) and y not in eligibility["grad_years"]:
                        eligibility["grad_years"].append(y)
                if eligibility["location"] is None and le.get("location"):
                    eligibility["location"] = str(le["location"])

    return {"title": title,
            "required_skills": sorted(req.values(), key=lambda r: (-r["weight"], r["name"])),
            "experience": experience,
            "eligibility": eligibility,
            "unmapped_terms": unmapped,
            "extraction_source": source}
