"""Resume intelligence. Layer A: deterministic taxonomy dictionary scan (always runs).
Layer B: optional LLM (enhancement only). Any LLM problem -> Layer A result is returned."""
import re
from datetime import date

from shared.llm import llm_json
from skill_intelligence.normalization import normalize
from skill_intelligence.taxonomy import all_skills, get_name

_MON = r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
MONTHS = {m: i + 1 for i, m in enumerate(
    ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"])}
_RANGE = re.compile(
    _MON + r"[a-z]*[\s.]+(20\d{2})\s*(?:-|–|—|to)\s*(?:" + _MON + r"[a-z]*[\s.]+(20\d{2})|(present|current|now|ongoing))",
    re.I)
_DEGREES = [(r"\bb\.?\s?tech\b", "B.Tech"), (r"\bb\.?e\b", "B.E"), (r"\bm\.?tech\b", "M.Tech"),
            (r"\bm\.?ca\b", "MCA"), (r"\bbca\b", "BCA"), (r"\bb\.?sc\b", "B.Sc"),
            (r"\bm\.?sc\b", "M.Sc"), (r"\bph\.?d\b", "PhD"), (r"\bmba\b", "MBA")]
_BRANCH_PHRASES = [(r"computer science", "CSE"), (r"information technology", "IT"),
                   (r"electronics (?:and|&)? communication", "ECE"), (r"mechanical", "MECH")]
_BRANCH_ABBR = ["CSE", "ECE", "EEE", "IT"]
_CGPA = re.compile(r"(?:cgpa|gpa)\s*[:\-]?\s*(10(?:\.\d+)?|\d(?:\.\d+)?)", re.I)
_GRAD = re.compile(r"(?:class of\s+)?(20\d{2})\s*(?:batch|passing|graduat)|class of (20\d{2})", re.I)
_CERT_LINE = re.compile(r"certif|coursera|udemy|nptel|aws certified|google cloud|microsoft certified|oracle certified", re.I)

_TERM_SID = {}
_TERM_RX = None


def _global_pattern():
    """One regex for the whole taxonomy, longest terms first, so 'node.js' is
    consumed by the Node.js alias and the bare 'js' alias cannot double-match."""
    global _TERM_RX
    if _TERM_RX is None:
        terms = []
        for s in all_skills():
            for t in [s["name"]] + s.get("aliases", []):
                _TERM_SID[t.lower()] = s["id"]
                terms.append(t)
        terms.sort(key=len, reverse=True)
        _TERM_RX = re.compile(r"\b(?:" + "|".join(re.escape(t) for t in terms) + r")\b", re.I)
    return _TERM_RX


def scan(text: str):
    """Returns (hits: {skill_id: count}, spans: [(start, end, skill_id)])."""
    hits, spans = {}, []
    for m in _global_pattern().finditer(text):
        sid = _TERM_SID[m.group(0).lower()]
        hits[sid] = hits.get(sid, 0) + 1
        spans.append((m.start(), m.end(), sid))
    return hits, spans


def dictionary_scan(text: str) -> dict:
    return scan(text)[0]


def _prof_hint(count: int) -> float:
    return 0.75 if count >= 3 else (0.6 if count == 2 else 0.5)


def _experience_months(text: str) -> int:
    total = 0
    now = date.today()
    for m in _RANGE.finditer(text):
        m1, y1 = MONTHS[m.group(1).lower()], int(m.group(2))
        if m.group(5):
            m2, y2 = now.month, now.year
        else:
            m2, y2 = MONTHS[m.group(3).lower()], int(m.group(4))
        total += max(0, (y2 - y1) * 12 + (m2 - m1)) + 1
    return total


def _sections(text: str) -> dict:
    sec, cur = {}, "general"
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.isupper() and len(s) < 40:
            cur = s.lower()
            sec.setdefault(cur, [])
            continue
        sec.setdefault(cur, []).append(s)
    return sec


def _projects(text: str) -> list:
    sec = _sections(text)
    out = []
    for key, lines in sec.items():
        if "project" in key:
            for ln in lines:
                out.append(re.sub(r"^[-•*]\s*", "", ln)[:80])
    for ln in text.splitlines():
        if ln.strip().lower().startswith("project:") and ln.strip()[8:].strip() not in out:
            out.append(ln.strip()[8:].strip()[:80])
    return out


def _certifications(text: str) -> list:
    sec = _sections(text)
    out = []
    cert_sections = [k for k in sec if "certif" in k]
    for key in cert_sections:
        out.extend(re.sub(r"^[-•*]\s*", "", ln)[:80] for ln in sec[key])
    if not cert_sections:  # no explicit section: fall back to keyword lines
        for ln in text.splitlines():
            t = ln.strip()
            if _CERT_LINE.search(t) and t not in out:
                out.append(t[:80])
    return out


def _education(text: str) -> dict:
    edu = {"degree": None, "field": None, "grad_year": None, "cgpa": None}
    for rx, canon in _DEGREES:
        if re.search(rx, text, re.I):
            edu["degree"] = canon
            break
    for rx, canon in _BRANCH_PHRASES:
        if re.search(rx, text, re.I):
            edu["field"] = canon
            break
    if edu["field"] is None:
        for ab in _BRANCH_ABBR:
            if re.search(r"\b" + ab + r"\b", text):
                edu["field"] = ab
                break
    g = _GRAD.search(text)
    if g:
        edu["grad_year"] = int(g.group(1) or g.group(2))
    c = _CGPA.search(text)
    if c:
        edu["cgpa"] = float(c.group(1))
    return edu


RESUME_PROMPT = """Extract structured data from this resume text. Return ONLY JSON with keys:
"skills": list of skill names exactly as written,
"experience_months": integer total months of experience/internships,
"certifications": list of strings,
"projects": list of strings,
"education": object with "degree", "field", "grad_year", "cgpa" (null if absent).
Resume text:
{text}"""


def parse_resume(text: str, use_llm: bool = True) -> dict:
    hits = dictionary_scan(text)
    skills = [{"raw": get_name(sid), "skill_id": sid, "name": get_name(sid),
               "confidence": 0.95, "method": "dictionary",
               "proficiency_hint": _prof_hint(c)} for sid, c in sorted(hits.items())]
    months = _experience_months(text)
    certs = _certifications(text)
    projects = _projects(text)
    edu = _education(text)
    unmapped, source = [], "dictionary"

    if use_llm:
        data = llm_json(RESUME_PROMPT.format(text=text))
        if isinstance(data, dict):
            source = "llm+dictionary"
            seen = {s["skill_id"] for s in skills}
            for term in data.get("skills", []) or []:
                n = normalize(str(term))
                if n["skill_id"] and n["skill_id"] not in seen:
                    seen.add(n["skill_id"])
                    skills.append({"raw": str(term), "skill_id": n["skill_id"], "name": n["name"],
                                   "confidence": round(0.9 * n["score"], 3), "method": n["method"],
                                   "proficiency_hint": 0.5})
                elif not n["skill_id"]:
                    unmapped.append(str(term))
            lm = data.get("experience_months")
            if isinstance(lm, (int, float)):
                months = max(months, int(lm))
            for c in data.get("certifications", []) or []:
                if str(c) not in certs:
                    certs.append(str(c)[:80])
            for p in data.get("projects", []) or []:
                if str(p) not in projects:
                    projects.append(str(p)[:80])
            le = data.get("education") or {}
            if isinstance(le, dict):
                for k in ("degree", "field", "grad_year", "cgpa"):
                    if edu.get(k) is None and le.get(k) is not None:
                        edu[k] = le.get(k)

    return {"skills": skills,
            "experience": {"total_months": months},
            "certifications": certs,
            "projects": projects,
            "education": edu,
            "unmapped_terms": unmapped,
            "extraction_source": source}
