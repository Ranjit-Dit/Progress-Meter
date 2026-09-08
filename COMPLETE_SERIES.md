# Progress AI Intelligence - COMPLETE CODE SERIES (Part 1 -> Part 8)

How to use: create the folder tree below, then copy each file in order.
Every file's exact path is given above its code block.

```bash
mkdir -p ai-intelligence/{shared,app,tests,samples} \
  ai-intelligence/skill_intelligence/{taxonomy,normalization,extraction,proficiency,scoring,skill_gap,readiness,priority_gap} \
  ai-intelligence/internship_intelligence/{extraction,eligibility,matching,compatibility,ranking,recommendation}
cd ai-intelligence
# these four files are intentionally EMPTY:
touch shared/__init__.py app/__init__.py skill_intelligence/__init__.py internship_intelligence/__init__.py
```

---

## PART 1 - Skeleton + taxonomy seed (single source of truth)

*VERIFY: pip install -r requirements.txt  &&  python3 -c "from skill_intelligence.taxonomy import all_skills; print(len(all_skills()), 'skills loaded')"*

##### `requirements.txt`
```text
fastapi>=0.110
uvicorn[standard]>=0.29
rapidfuzz>=3.6
pytest>=8.0
httpx>=0.27
# OPTIONAL - semantic fallback only (heavy, install only if you want embedding matching):
# sentence-transformers>=2.7
```

##### `skill_intelligence/taxonomy/skills.json`
```json
[
  {"id": "sk_linux", "name": "Linux", "category": "DevOps", "aliases": ["ubuntu", "centos", "bash", "shell", "linux os"]},
  {"id": "sk_git", "name": "Git", "category": "DevOps", "aliases": ["git version control", "git scm"]},
  {"id": "sk_networking", "name": "Computer Networks", "category": "Core CS", "aliases": ["networking", "tcp/ip", "http", "computer network"]},
  {"id": "sk_docker", "name": "Docker", "category": "DevOps", "aliases": ["containers", "containerization", "dockerfile", "docker compose"]},
  {"id": "sk_kubernetes", "name": "Kubernetes", "category": "DevOps", "aliases": ["k8s", "kube", "kubernates"]},
  {"id": "sk_aws", "name": "AWS", "category": "Cloud", "aliases": ["amazon web services", "amazon aws", "aws cloud"]},
  {"id": "sk_terraform", "name": "Terraform", "category": "DevOps", "aliases": ["terraform iac"]},
  {"id": "sk_ci_cd", "name": "CI/CD", "category": "DevOps", "aliases": ["ci-cd", "cicd", "continuous integration", "continuous delivery", "jenkins", "github actions"]},
  {"id": "sk_python", "name": "Python", "category": "Backend", "aliases": ["python3", "py"]},
  {"id": "sk_java", "name": "Java", "category": "Backend", "aliases": ["core java", "java se"]},
  {"id": "sk_node", "name": "Node.js", "category": "Backend", "aliases": ["node", "nodejs", "express", "express.js"]},
  {"id": "sk_django", "name": "Django", "category": "Backend", "aliases": ["django rest framework", "drf"]},
  {"id": "sk_flask", "name": "Flask", "category": "Backend", "aliases": ["flask api"]},
  {"id": "sk_fastapi", "name": "FastAPI", "category": "Backend", "aliases": ["fast api"]},
  {"id": "sk_rest", "name": "REST APIs", "category": "Backend", "aliases": ["rest", "restful", "api development", "rest api"]},
  {"id": "sk_sql", "name": "SQL", "category": "Database", "aliases": ["mysql", "plsql", "sql queries"]},
  {"id": "sk_postgresql", "name": "PostgreSQL", "category": "Database", "aliases": ["postgres", "psql"]},
  {"id": "sk_mongodb", "name": "MongoDB", "category": "Database", "aliases": ["mongo", "mongo db"]},
  {"id": "sk_redis", "name": "Redis", "category": "Database", "aliases": ["redis cache"]},
  {"id": "sk_kafka", "name": "Kafka", "category": "Backend", "aliases": ["apache kafka"]},
  {"id": "sk_microservices", "name": "Microservices", "category": "Backend", "aliases": ["microservice architecture", "micro services"]},
  {"id": "sk_spring", "name": "Spring Boot", "category": "Backend", "aliases": ["spring", "springboot", "spring framework"]},
  {"id": "sk_html", "name": "HTML", "category": "Frontend", "aliases": ["html5"]},
  {"id": "sk_css", "name": "CSS", "category": "Frontend", "aliases": ["css3", "tailwind", "tailwind css", "bootstrap"]},
  {"id": "sk_js", "name": "JavaScript", "category": "Frontend", "aliases": ["js", "es6", "javascript es6"]},
  {"id": "sk_ts", "name": "TypeScript", "category": "Frontend", "aliases": ["ts"]},
  {"id": "sk_react", "name": "React", "category": "Frontend", "aliases": ["reactjs", "react.js", "react js", "react library"]},
  {"id": "sk_flutter", "name": "Flutter", "category": "Mobile", "aliases": ["dart", "flutter sdk"]},
  {"id": "sk_ml", "name": "Machine Learning", "category": "Data & AI", "aliases": ["ml", "machine learning models"]},
  {"id": "sk_pandas", "name": "Pandas", "category": "Data & AI", "aliases": ["pandas python"]},
  {"id": "sk_numpy", "name": "NumPy", "category": "Data & AI", "aliases": ["numpy python"]},
  {"id": "sk_sklearn", "name": "scikit-learn", "category": "Data & AI", "aliases": ["sklearn", "scikit learn"]},
  {"id": "sk_dsa", "name": "Data Structures & Algorithms", "category": "Core CS", "aliases": ["dsa", "data structures", "algorithms", "data structures and algorithms"]},
  {"id": "sk_dbms", "name": "DBMS", "category": "Core CS", "aliases": ["database management systems", "database management"]},
  {"id": "sk_os", "name": "Operating Systems", "category": "Core CS", "aliases": ["os", "operating system"]},
  {"id": "sk_oop", "name": "OOP", "category": "Core CS", "aliases": ["oops", "object oriented programming", "object-oriented programming"]}
]
```

##### `skill_intelligence/taxonomy/taxonomy.py`
```python
"""Single source of truth for canonical skill names, categories and aliases."""
import functools
import json
from pathlib import Path

DATA = Path(__file__).parent / "skills.json"


@functools.lru_cache(maxsize=1)
def _load():
    with open(DATA, encoding="utf-8") as f:
        skills = json.load(f)
    name_idx, alias_idx, corpus, id_idx = {}, {}, {}, {}
    for s in skills:
        sid, nm = s["id"], s["name"]
        id_idx[sid] = s
        name_idx[nm.lower()] = sid
        corpus[nm.lower()] = sid
        for a in s.get("aliases", []):
            alias_idx[a.lower()] = sid
            corpus[a.lower()] = sid
    return skills, name_idx, alias_idx, corpus, id_idx


def all_skills():
    return _load()[0]


def name_index():
    return _load()[1]


def alias_index():
    return _load()[2]


def fuzzy_corpus():
    return _load()[3]


def get_skill(skill_id):
    return _load()[4].get(skill_id)


def get_name(skill_id):
    s = get_skill(skill_id)
    return s["name"] if s else skill_id
```

##### `skill_intelligence/taxonomy/__init__.py`
```python
from .taxonomy import all_skills, get_skill, get_name, name_index, alias_index, fuzzy_corpus
```

---

## PART 2 - Normalization engine + scoring core

*VERIFY: python3 -c "from skill_intelligence.normalization import normalize as n; print([(t, n(t)['skill_id'], n(t)['method']) for t in ['ReactJS','k8s','kubernets']])"*

##### `shared/llm.py`
```python
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
```

##### `skill_intelligence/normalization/normalize.py`
```python
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
```

##### `skill_intelligence/normalization/__init__.py`
```python
from .normalize import normalize, normalize_many, clean
```

##### `skill_intelligence/proficiency/proficiency.py`
```python
"""Proficiency levels <-> 0..1 scores. Assessment results overwrite resume hints later."""
LEVELS = {"beginner": 0.25, "intermediate": 0.5, "good": 0.75, "expert": 1.0}


def level_to_score(level) -> float:
    if isinstance(level, (int, float)):
        return max(0.0, min(1.0, float(level)))
    return LEVELS.get(str(level).strip().lower(), 0.5)


def score_to_level(score: float) -> str:
    if score >= 0.875:
        return "expert"
    if score >= 0.625:
        return "good"
    if score >= 0.375:
        return "intermediate"
    return "beginner"
```

##### `skill_intelligence/proficiency/__init__.py`
```python
from .proficiency import LEVELS, level_to_score, score_to_level
```

##### `skill_intelligence/scoring/scoring.py`
```python
"""The one scoring formula used by BOTH readiness and compatibility:
credit = min(1, proficiency / min_proficiency), 0 if skill absent
score  = 100 * sum(weight * credit) / sum(weight)"""


def credit(proficiency, min_proficiency) -> float:
    if proficiency is None or proficiency <= 0:
        return 0.0
    mp = max(float(min_proficiency or 0), 0.05)
    return round(min(1.0, float(proficiency) / mp), 4)


def status_of(c: float) -> str:
    if c >= 1.0:
        return "matched"
    return "partial" if c > 0 else "missing"


def compute_score(rows):
    earned = sum(r["weight"] * r["credit"] for r in rows)
    possible = sum(r["weight"] for r in rows)
    score = round(100.0 * earned / possible, 1) if possible else 0.0
    return score, round(earned, 4), round(possible, 4)
```

##### `skill_intelligence/scoring/__init__.py`
```python
from .scoring import credit, status_of, compute_score
```

---

## PART 3 - Gap, readiness & priority engines

*VERIFY: python3 -c "from skill_intelligence.readiness import readiness as R; print(R({'sk_linux':1.0},[{'skill_id':'sk_linux','weight':1.0,'min_proficiency':0.6},{'skill_id':'sk_docker','weight':1.0,'min_proficiency':0.5}])['readiness'])"  -> 50.0*

##### `skill_intelligence/skill_gap/gap.py`
```python
"""Core comparison: student skills vs required skills -> explainable rows + score."""
from skill_intelligence.scoring import compute_score, credit, status_of
from skill_intelligence.taxonomy import get_name


def compare(student_skills: dict, required: list) -> dict:
    rows = []
    for r in required:
        sid = r["skill_id"]
        prof = student_skills.get(sid)
        min_prof = float(r.get("min_proficiency", 0.5))
        weight = float(r.get("weight", 1.0))
        c = credit(prof, min_prof)
        rows.append({
            "skill_id": sid,
            "name": get_name(sid),
            "your_proficiency": prof if prof is not None else 0.0,
            "required": min_prof,
            "weight": weight,
            "credit": c,
            "status": status_of(c),
        })
    score, earned, possible = compute_score(rows)
    return {"rows": rows, "score": score, "earned": earned, "possible": possible}
```

##### `skill_intelligence/skill_gap/__init__.py`
```python
from .gap import compare
```

##### `skill_intelligence/readiness/readiness.py`
```python
"""Career-role readiness: same formula as compatibility, applied to a target role."""
from skill_intelligence.skill_gap.gap import compare


def readiness(student_skills: dict, role_requirements: list) -> dict:
    res = compare(student_skills, role_requirements)
    gaps = [r for r in res["rows"] if r["credit"] < 1.0]
    return {
        "readiness": res["score"],
        "rows": res["rows"],
        "gaps": gaps,
        "explanation": {
            "formula": "readiness = 100 * sum(weight x credit) / sum(weight)",
            "credit_rule": "credit = min(1, proficiency / min_proficiency); 0 if skill absent",
            "earned": res["earned"],
            "possible": res["possible"],
        },
    }
```

##### `skill_intelligence/readiness/__init__.py`
```python
from .readiness import readiness
```

##### `skill_intelligence/priority_gap/priority.py`
```python
"""Priority gaps: order by the readiness points each gap can still recover
(gain = weight x (1 - credit)) - closing the top gap raises the score the most.
Ties: absent before partial, then name."""


def prioritize(rows: list) -> list:
    gaps = [r for r in rows if r.get("credit", 0.0) < 1.0]
    gaps.sort(key=lambda r: (-round(r["weight"] * (1.0 - r["credit"]), 4),
                             0 if r["status"] == "missing" else 1, r["name"]))
    return [{
        "skill_id": r["skill_id"],
        "name": r["name"],
        "weight": r["weight"],
        "severity": "absent" if r["status"] == "missing" else "partial",
        "current": r["your_proficiency"],
        "required": r["required"],
        "recoverable_points": round(100.0 * r["weight"] * (1.0 - r["credit"])
                                    / max(sum(x["weight"] for x in rows), 1e-9), 1),
    } for r in gaps]
```

##### `skill_intelligence/priority_gap/__init__.py`
```python
from .priority import prioritize
```

---

## PART 4 - Extraction engines (resume + JD + eligibility)

*VERIFY: python3 -c "from skill_intelligence.extraction import parse_resume as P; print([s['name'] for s in P('SKILLS\\nReactJS, node.js, Docker', use_llm=False)['skills']])"*

##### `skill_intelligence/extraction/resume_parser.py`
```python
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
```

##### `skill_intelligence/extraction/__init__.py`
```python
from .resume_parser import parse_resume
```

##### `internship_intelligence/extraction/jd_parser.py`
```python
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
```

##### `internship_intelligence/extraction/__init__.py`
```python
from .jd_parser import parse_jd
```

##### `internship_intelligence/eligibility/eligibility.py`
```python
"""Hard eligibility checks. Every rule is returned with passed + detail (explainable).
A constraint the student's data cannot answer is NOT used to reject (passed=True,
detail says data not provided) - the backend/UI can tighten this later."""


def check(meta: dict, elig: dict) -> dict:
    meta = meta or {}
    elig = elig or {}
    checks = []

    def add(rule, passed, detail):
        checks.append({"rule": rule, "passed": bool(passed), "detail": detail})

    if elig.get("degrees"):
        d = meta.get("degree")
        add("degree in " + ", ".join(elig["degrees"]),
            d is None or d in elig["degrees"],
            f"student degree: {d or 'not provided'}")
    if elig.get("branches"):
        b = meta.get("branch") or meta.get("field")
        add("branch in " + ", ".join(elig["branches"]),
            b is None or b in elig["branches"],
            f"student branch: {b or 'not provided'}")
    if elig.get("min_cgpa") is not None:
        c = meta.get("cgpa")
        add(f"cgpa >= {elig['min_cgpa']}",
            c is None or float(c) >= float(elig["min_cgpa"]),
            f"student cgpa: {c if c is not None else 'not provided'}")
    if elig.get("grad_years"):
        y = meta.get("grad_year")
        add("grad year in " + ", ".join(map(str, elig["grad_years"])),
            y is None or int(y) in elig["grad_years"],
            f"student grad year: {y if y is not None else 'not provided'}")
    if elig.get("location"):
        loc = meta.get("location")
        add(f"location = {elig['location']}",
            loc is None or str(loc).strip().lower() == str(elig["location"]).strip().lower(),
            f"student location: {loc or 'not provided'}")
    return {"eligible": all(c["passed"] for c in checks), "checks": checks}
```

##### `internship_intelligence/eligibility/__init__.py`
```python
from .eligibility import check
```

---

## PART 5 - Matching, compatibility, ranking, recommendations

*VERIFY: see tests/test_match.py (score 50.0 case) - or run pytest after Part 7*

##### `internship_intelligence/matching/matcher.py`
```python
"""Student profile vs internship requirement comparison (delegates to the shared
gap engine so readiness and compatibility can never drift apart)."""
from skill_intelligence.skill_gap.gap import compare


def match(student_skills: dict, required_skills: list) -> dict:
    return compare(student_skills, required_skills or [])
```

##### `internship_intelligence/matching/__init__.py`
```python
from .matcher import match
```

##### `internship_intelligence/compatibility/compatibility.py`
```python
"""Explainable compatibility result: score + eligibility + matched/partial/missing
buckets + formula breakdown. No score is ever returned without its explanation."""
from internship_intelligence.eligibility.eligibility import check as eligibility_check
from internship_intelligence.matching.matcher import match

FORMULA = "score = 100 * sum(weight x credit) / sum(weight)"
CREDIT_RULE = "credit = min(1, proficiency / min_proficiency); 0 if skill absent"


def compatibility(student_skills: dict, opportunity: dict, student_meta: dict = None) -> dict:
    res = match(student_skills, opportunity.get("required_skills", []))
    elig = eligibility_check(student_meta, opportunity.get("eligibility"))
    buckets = {"matched": [], "partial": [], "missing": []}
    for row in res["rows"]:
        buckets[row["status"]].append(row)
    return {
        "opportunity_id": opportunity.get("opportunity_id"),
        "title": opportunity.get("title"),
        "compatibility_score": res["score"],
        "eligible": elig["eligible"],
        "eligibility_checks": elig["checks"],
        "matched": buckets["matched"],
        "partial": buckets["partial"],
        "missing": buckets["missing"],
        "explanation": {
            "formula": FORMULA,
            "credit_rule": CREDIT_RULE,
            "earned": res["earned"],
            "possible": res["possible"],
        },
    }
```

##### `internship_intelligence/compatibility/__init__.py`
```python
from .compatibility import compatibility
```

##### `internship_intelligence/ranking/ranking.py`
```python
"""Rank opportunities: score desc, tie-break fewer missing must-haves, then stable id."""


def rank(results: list) -> list:
    def key(r):
        missing_must = sum(1 for m in r.get("missing", []) if m.get("weight", 0) >= 1.0)
        return (-r.get("compatibility_score", 0.0), missing_must,
                str(r.get("opportunity_id")))
    return sorted(results, key=key)
```

##### `internship_intelligence/ranking/__init__.py`
```python
from .ranking import rank
```

##### `internship_intelligence/recommendation/learning_resources.json`
```json
{
  "courses": [
    {"id": 1, "title": "Docker Fundamentals", "skill_ids": ["sk_docker"], "hours": 12},
    {"id": 2, "title": "Kubernetes Basics", "skill_ids": ["sk_kubernetes", "sk_docker"], "hours": 16},
    {"id": 3, "title": "AWS Cloud Practitioner Prep", "skill_ids": ["sk_aws"], "hours": 20},
    {"id": 4, "title": "Terraform Zero to Hero", "skill_ids": ["sk_terraform"], "hours": 10},
    {"id": 5, "title": "CI/CD with GitHub Actions", "skill_ids": ["sk_ci_cd"], "hours": 8},
    {"id": 6, "title": "React - The Complete Guide", "skill_ids": ["sk_react", "sk_js"], "hours": 24},
    {"id": 7, "title": "Node.js Backend Development", "skill_ids": ["sk_node", "sk_rest"], "hours": 18},
    {"id": 8, "title": "SQL & PostgreSQL Bootcamp", "skill_ids": ["sk_sql", "sk_postgresql"], "hours": 14},
    {"id": 9, "title": "Python Refresher", "skill_ids": ["sk_python"], "hours": 10},
    {"id": 10, "title": "Machine Learning Foundations", "skill_ids": ["sk_ml", "sk_pandas"], "hours": 30}
  ],
  "projects": [
    {"id": 1, "title": "Containerize a Flask API", "skill_ids": ["sk_docker", "sk_flask"]},
    {"id": 2, "title": "Deploy a React App on AWS", "skill_ids": ["sk_react", "sk_aws"]},
    {"id": 3, "title": "Build a CI Pipeline for a Node App", "skill_ids": ["sk_ci_cd", "sk_node"]},
    {"id": 4, "title": "K8s Deployment of a Microservice", "skill_ids": ["sk_kubernetes", "sk_docker"]},
    {"id": 5, "title": "Provision Infra with Terraform", "skill_ids": ["sk_terraform"]},
    {"id": 6, "title": "CRUD REST API with Django", "skill_ids": ["sk_django", "sk_rest", "sk_postgresql"]},
    {"id": 7, "title": "Campus Dashboard in React", "skill_ids": ["sk_react", "sk_css"]},
    {"id": 8, "title": "Price Predictor with Pandas", "skill_ids": ["sk_ml", "sk_pandas"]}
  ],
  "assessments": [
    {"id": 1, "title": "Docker Assessment", "skill_ids": ["sk_docker"]},
    {"id": 2, "title": "Kubernetes Assessment", "skill_ids": ["sk_kubernetes"]},
    {"id": 3, "title": "AWS Assessment", "skill_ids": ["sk_aws"]},
    {"id": 4, "title": "Terraform Assessment", "skill_ids": ["sk_terraform"]},
    {"id": 5, "title": "CI/CD Assessment", "skill_ids": ["sk_ci_cd"]},
    {"id": 6, "title": "React Assessment", "skill_ids": ["sk_react"]},
    {"id": 7, "title": "SQL Assessment", "skill_ids": ["sk_sql"]},
    {"id": 8, "title": "Python Assessment", "skill_ids": ["sk_python"]}
  ]
}
```

##### `internship_intelligence/recommendation/recommendation.py`
```python
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
```

##### `internship_intelligence/recommendation/__init__.py`
```python
from .recommendation import recommend
```

---

## PART 6 - API layer (frozen contracts for UI/backend/DB teammates)

*VERIFY: python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000  ->  open /docs*

##### `app/schemas.py`
```python
"""Frozen request/response contracts. UI + backend + DB teammates build against these."""
from typing import Optional

from pydantic import BaseModel, Field


class StudentSkill(BaseModel):
    skill_id: str
    proficiency: float = Field(ge=0, le=1)


class StudentMeta(BaseModel):
    degree: Optional[str] = None
    branch: Optional[str] = None
    cgpa: Optional[float] = None
    grad_year: Optional[int] = None
    location: Optional[str] = None


class Student(BaseModel):
    student_id: Optional[int] = None
    skills: list[StudentSkill] = []
    meta: Optional[StudentMeta] = None


class RequiredSkill(BaseModel):
    skill_id: str
    weight: float = 1.0
    min_proficiency: float = 0.5


class Eligibility(BaseModel):
    degrees: Optional[list[str]] = None
    branches: Optional[list[str]] = None
    min_cgpa: Optional[float] = None
    grad_years: Optional[list[int]] = None
    location: Optional[str] = None


class Opportunity(BaseModel):
    opportunity_id: Optional[int] = None
    title: Optional[str] = None
    required_skills: list[RequiredSkill] = []
    eligibility: Optional[Eligibility] = None


class MatchRequest(BaseModel):
    student: Student
    opportunity: Opportunity


class BatchMatchRequest(BaseModel):
    student: Student
    opportunities: list[Opportunity] = []


class SkillGapRequest(BaseModel):
    student: Student
    role_requirements: list[RequiredSkill] = []


class NormalizeRequest(BaseModel):
    terms: list[str]


class ExtractResumeRequest(BaseModel):
    resume_text: str
    use_llm: bool = True


class ExtractJDRequest(BaseModel):
    jd_text: str
    use_llm: bool = True


class GapItem(BaseModel):
    skill_id: str
    weight: float = 1.0


class RecommendRequest(BaseModel):
    gaps: list[GapItem]
    types: Optional[list[str]] = None
    limit: int = 3
    opportunities: Optional[list[Opportunity]] = None
```

##### `app/main.py`
```python
"""Progress AI Intelligence microservice (FastAPI). Stateless: no DB access here.
The main backend hydrates payloads from PostgreSQL and calls these endpoints."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import (BatchMatchRequest, ExtractJDRequest, ExtractResumeRequest,
                         MatchRequest, NormalizeRequest, RecommendRequest, SkillGapRequest)
from internship_intelligence.compatibility import compatibility
from internship_intelligence.extraction import parse_jd
from internship_intelligence.ranking import rank
from internship_intelligence.recommendation import recommend
from skill_intelligence.extraction import parse_resume
from skill_intelligence.normalization import normalize_many
from skill_intelligence.priority_gap import prioritize
from skill_intelligence.readiness import readiness
from skill_intelligence.taxonomy import all_skills

app = FastAPI(title="Progress AI Intelligence", version="1.0.0")

# NOTE for security owner: tighten origins to the web app's domain before production.
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])


def _student_skills(student) -> dict:
    return {s.skill_id: s.proficiency for s in student.skills}


def _meta(student):
    return student.meta.model_dump() if student.meta else None


def _opp_dict(opp) -> dict:
    d = opp.model_dump()
    return d


@app.get("/")
def root():
    return {"service": "Progress AI Intelligence", "version": "1.0.0",
            "endpoints": ["/ai/skills", "/ai/skills/normalize", "/ai/resume/extract",
                          "/ai/opportunity/extract", "/ai/match", "/ai/matches/batch",
                          "/ai/skill-gap", "/ai/recommendations"]}


@app.get("/ai/skills")
def get_skills():
    return all_skills()


@app.post("/ai/skills/normalize")
def post_normalize(req: NormalizeRequest):
    return {"results": normalize_many(req.terms)}


@app.post("/ai/resume/extract")
def post_resume(req: ExtractResumeRequest):
    return parse_resume(req.resume_text, use_llm=req.use_llm)


@app.post("/ai/opportunity/extract")
def post_jd(req: ExtractJDRequest):
    return parse_jd(req.jd_text, use_llm=req.use_llm)


@app.post("/ai/match")
def post_match(req: MatchRequest):
    return compatibility(_student_skills(req.student), _opp_dict(req.opportunity),
                         _meta(req.student))


@app.post("/ai/matches/batch")
def post_batch(req: BatchMatchRequest):
    results = [compatibility(_student_skills(req.student), _opp_dict(o), _meta(req.student))
               for o in req.opportunities]
    return {"results": rank(results)}


@app.post("/ai/skill-gap")
def post_skill_gap(req: SkillGapRequest):
    res = readiness(_student_skills(req.student),
                    [r.model_dump() for r in req.role_requirements])
    res["priority_gaps"] = prioritize(res["rows"])
    return res


@app.post("/ai/recommendations")
def post_recommend(req: RecommendRequest):
    gaps = [g.model_dump() for g in req.gaps]
    opps = [_opp_dict(o) for o in req.opportunities] if req.opportunities else None
    return recommend(gaps, types=req.types, limit=req.limit, opportunities=opps)
```

---

## PART 7 - Tests (your zero-error gate: must print 17 passed)

*VERIFY: python3 -m pytest tests/ -q*

##### `tests/conftest.py`
```python
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
os.environ.pop("OPENAI_API_KEY", None)  # tests always run the deterministic path
```

##### `tests/test_normalize.py`
```python
from skill_intelligence.normalization import normalize


def test_exact():
    r = normalize("React")
    assert r["skill_id"] == "sk_react" and r["method"] == "exact"


def test_alias_spellings():
    for term in ("ReactJS", "react.js", "react js"):
        r = normalize(term)
        assert r["skill_id"] == "sk_react", term
        assert r["method"] == "alias"
    assert normalize("k8s")["skill_id"] == "sk_kubernetes"
    assert normalize("node.js")["skill_id"] == "sk_node"


def test_fuzzy_typo():
    r = normalize("kubernets")
    assert r["skill_id"] == "sk_kubernetes"
    assert r["method"] == "fuzzy"


def test_unmapped_never_scores():
    r = normalize("quantum cobol wizardry")
    assert r["skill_id"] is None and r["method"] == "unmapped"
```

##### `tests/test_match.py`
```python
from internship_intelligence.compatibility import compatibility
from internship_intelligence.ranking import rank

STU = {"sk_linux": 1.0, "sk_git": 0.4}
OPP = {
    "opportunity_id": 7,
    "title": "DevOps Intern",
    "required_skills": [
        {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 1.0},
        {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.8},
        {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
    ],
    "eligibility": {"min_cgpa": 7.0},
}


def test_score_and_buckets():
    r = compatibility(STU, OPP, {"cgpa": 8.1, "degree": "B.Tech"})
    assert r["compatibility_score"] == 50.0          # earned 1.5 / possible 3
    assert r["eligible"] is True
    assert len(r["matched"]) == 1 and r["matched"][0]["skill_id"] == "sk_linux"
    assert len(r["partial"]) == 1 and r["partial"][0]["credit"] == 0.5
    assert len(r["missing"]) == 1 and r["missing"][0]["skill_id"] == "sk_docker"
    assert r["explanation"]["earned"] == 1.5 and r["explanation"]["possible"] == 3


def test_eligibility_fail_keeps_score():
    r = compatibility(STU, OPP, {"cgpa": 6.0})
    assert r["eligible"] is False
    assert r["compatibility_score"] == 50.0
    assert any(c["rule"].startswith("cgpa") and not c["passed"] for c in r["eligibility_checks"])


def test_full_and_empty():
    full = compatibility({"sk_linux": 1.0, "sk_git": 1.0, "sk_docker": 1.0}, OPP, None)
    assert full["compatibility_score"] == 100.0
    empty = compatibility({}, OPP, None)
    assert empty["compatibility_score"] == 0.0


def test_ranking_order():
    a = compatibility({"sk_linux": 1.0}, OPP, None)
    b = compatibility({"sk_linux": 1.0, "sk_git": 1.0, "sk_docker": 1.0}, OPP, None)
    out = rank([a, b])
    assert out[0]["compatibility_score"] == 100.0
```

##### `tests/test_extract.py`
```python
from internship_intelligence.extraction import parse_jd
from skill_intelligence.extraction import parse_resume

RESUME = """EDUCATION
B.Tech Computer Science, 2026 batch, CGPA: 8.1
SKILLS
ReactJS, node.js, Python, SQL
EXPERIENCE
SDE Intern, XYZ - Jun 2024 - Aug 2024
PROJECTS
Campus Portal - a react based portal
CERTIFICATIONS
AWS Cloud Practitioner (2025)
"""

JD = """DevOps Intern
Must have Docker and Linux. Good to have Terraform.
Requires 6+ months of experience.
Eligibility: B.Tech CSE 2026 batch, CGPA 7.0+
"""


def test_resume_dictionary_layer():
    r = parse_resume(RESUME, use_llm=False)
    ids = {s["skill_id"] for s in r["skills"]}
    assert {"sk_react", "sk_node", "sk_python", "sk_sql", "sk_aws"} <= ids
    assert "sk_js" not in ids  # 'node.js' must not double-match the bare 'js' alias
    assert r["extraction_source"] == "dictionary"
    assert r["experience"]["total_months"] == 3
    assert r["education"]["degree"] == "B.Tech"
    assert r["education"]["cgpa"] == 8.1
    assert r["education"]["grad_year"] == 2026
    assert any("AWS Cloud Practitioner" in c for c in r["certifications"])
    assert any("Campus Portal" in p for p in r["projects"])


def test_jd_weights_and_eligibility():
    r = parse_jd(JD, use_llm=False)
    by_id = {s["skill_id"]: s for s in r["required_skills"]}
    assert by_id["sk_docker"]["weight"] == 1.0
    assert by_id["sk_linux"]["weight"] == 1.0
    assert by_id["sk_terraform"]["weight"] == 0.5
    assert r["experience"]["min_months"] == 6
    e = r["eligibility"]
    assert "B.Tech" in e["degrees"]
    assert "CSE" in e["branches"]
    assert e["min_cgpa"] == 7.0
    assert 2026 in e["grad_years"]
```

##### `tests/test_recommend.py`
```python
from internship_intelligence.recommendation import recommend
from skill_intelligence.priority_gap import prioritize

GAPS = [{"skill_id": "sk_docker", "weight": 1.0},
        {"skill_id": "sk_terraform", "weight": 0.5}]
OPPS = [{"opportunity_id": 9, "title": "Cloud Ops Intern",
         "required_skills": [{"skill_id": "sk_docker"}, {"skill_id": "sk_terraform"}]}]


def test_recommend_covers_and_reasons():
    r = recommend(GAPS, limit=3, opportunities=OPPS)
    assert r["courses"][0]["score"] >= 1.0
    assert "sk_docker" in r["courses"][0]["covers"]
    assert "Docker" in r["courses"][0]["reason"]
    assert r["internships"][0]["score"] == 1.5
    assert r["roadmap"][0]["skill_id"] == "sk_docker"
    types = [c["type"] for c in r["roadmap"][0]["chain"]]
    assert types == ["course", "project", "assessment"]


def test_prioritize_order():
    rows = [
        {"skill_id": "sk_terraform", "name": "Terraform", "weight": 0.5, "credit": 0.0,
         "status": "missing", "your_proficiency": 0.0, "required": 0.3},
        {"skill_id": "sk_docker", "name": "Docker", "weight": 1.0, "credit": 0.4,
         "status": "partial", "your_proficiency": 0.2, "required": 0.5},
        {"skill_id": "sk_linux", "name": "Linux", "weight": 1.0, "credit": 1.0,
         "status": "matched", "your_proficiency": 1.0, "required": 0.6},
    ]
    p = prioritize(rows)
    assert [g["skill_id"] for g in p] == ["sk_docker", "sk_terraform"]
    assert p[0]["severity"] == "partial" and p[1]["severity"] == "absent"
```

##### `tests/test_api.py`
```python
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_skills_endpoint():
    r = client.get("/ai/skills")
    assert r.status_code == 200 and len(r.json()) >= 30


def test_normalize_endpoint():
    r = client.post("/ai/skills/normalize", json={"terms": ["ReactJS", "k8s", "zzzunknown"]})
    out = r.json()["results"]
    assert out[0]["skill_id"] == "sk_react"
    assert out[1]["skill_id"] == "sk_kubernetes"
    assert out[2]["skill_id"] is None


def test_match_endpoint():
    body = {
        "student": {"student_id": 1, "meta": {"cgpa": 8.1},
                    "skills": [{"skill_id": "sk_linux", "proficiency": 1.0},
                               {"skill_id": "sk_git", "proficiency": 0.4}]},
        "opportunity": {"opportunity_id": 7, "title": "DevOps Intern",
                        "required_skills": [
                            {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 1.0},
                            {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.8},
                            {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5}],
                        "eligibility": {"min_cgpa": 7.0}},
    }
    r = client.post("/ai/match", json=body)
    assert r.status_code == 200
    j = r.json()
    assert j["compatibility_score"] == 50.0 and j["eligible"] is True
    assert "formula" in j["explanation"]


def test_resume_and_jd_endpoints():
    r = client.post("/ai/resume/extract",
                    json={"resume_text": "SKILLS\nReactJS, Docker\n", "use_llm": False})
    ids = {s["skill_id"] for s in r.json()["skills"]}
    assert {"sk_react", "sk_docker"} <= ids
    j = client.post("/ai/opportunity/extract",
                    json={"jd_text": "Must have Docker.\n", "use_llm": False}).json()
    assert j["required_skills"][0]["skill_id"] == "sk_docker"


def test_skill_gap_and_recommendations():
    r = client.post("/ai/skill-gap", json={
        "student": {"skills": [{"skill_id": "sk_linux", "proficiency": 1.0}]},
        "role_requirements": [{"skill_id": "sk_linux", "weight": 1.0},
                              {"skill_id": "sk_docker", "weight": 1.0}]})
    j = r.json()
    assert j["readiness"] == 50.0
    assert j["priority_gaps"][0]["skill_id"] == "sk_docker"
    rec = client.post("/ai/recommendations", json={
        "gaps": [{"skill_id": "sk_docker", "weight": 1.0}]}).json()
    assert rec["roadmap"][0]["chain"][0]["type"] == "course"
```

---

## PART 8 - Demo, samples & teammate docs

*VERIFY: python3 demo.py   and   bash samples/run_all.sh   (ends with ALL ENDPOINTS OK)*

##### `demo.py`
```python
"""End-to-end demo of the 6 AI behaviours against the RUNNING service.
Usage:  python3 demo.py [base_url]        (default http://localhost:8000)
Start the service first:  python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000"""
import json
import sys
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"

RESUME = """EDUCATION
B.Tech Computer Science, 2026 batch, CGPA: 8.1
SKILLS
Linux, Git, Networking, Docker, Kubernetes, AWS
EXPERIENCE
Cloud Intern, XYZ - Jun 2024 - Aug 2024
PROJECTS
Campus Portal - deployed with docker
CERTIFICATIONS
AWS Cloud Practitioner (2025)
"""

JD = """DevOps Intern
Must have Docker and Linux. Must have CI/CD. Good to have Terraform.
Kubernetes and AWS required with basic proficiency.
Eligibility: B.Tech CSE 2026 batch, CGPA 7.0+
"""

# Demo student vector (proficiency 0..1) - in production this comes from student_skills table
STUDENT = {"sk_linux": 0.8, "sk_git": 0.6, "sk_networking": 0.5,
           "sk_docker": 0.3, "sk_kubernetes": 0.25, "sk_aws": 0.22}
ROLE = [  # DevOps Engineer role requirements (career_role_skills in production)
    {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_networking", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_aws", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
]


def call(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE + path, data=data,
                                 headers={"Content-Type": "application/json"},
                                 method="POST" if payload is not None else "GET")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def head(t):
    print("\n" + "=" * 70 + f"\n{t}\n" + "=" * 70)


head("STEP 1 - Normalization: many spellings -> ONE official name")
for res in call("/ai/skills/normalize",
                {"terms": ["ReactJS", "react.js", "k8s", "node.js",
                           "kubernets", "quantum cobol"]})["results"]:
    print(f"  {res['input']:<14} -> {str(res['name']):<12} ({res['method']})")

head("STEP 2 - Resume intelligence: raw text -> clean structured data")
ex = call("/ai/resume/extract", {"resume_text": RESUME, "use_llm": False})
print("  skills      :", ", ".join(s["name"] for s in ex["skills"]))
print("  experience  :", ex["experience"]["total_months"], "months")
print("  education   :", ex["education"])
print("  certs       :", ex["certifications"])
print("  projects    :", ex["projects"])
print("  source      :", ex["extraction_source"], "(LLM optional - works without key)")

head("STEP 3 - Skill-gap + readiness for target role: DevOps Engineer")
gap = call("/ai/skill-gap", {"student": {"skills": [{"skill_id": k, "proficiency": v}
                                                    for k, v in STUDENT.items()]},
                             "role_requirements": ROLE})
for row in gap["rows"]:
    mark = {"matched": "OK ", "partial": "!! ", "missing": "XX "}[row["status"]]
    print(f"  [{mark}] {row['name']:<12} you={row['your_proficiency']:<4} "
          f"need={row['required']:<4} credit={row['credit']}")
print(f"\n  READINESS: {gap['readiness']}%")
print("  Priority gaps (biggest score gain first):")
for g in gap["priority_gaps"]:
    print(f"    - {g['name']:<10} severity={g['severity']:<7} "
          f"recoverable=+{g['recoverable_points']} pts")

head("STEP 4 - Job intelligence: JD -> weighted requirements + eligibility")
jd = call("/ai/opportunity/extract", {"jd_text": JD, "use_llm": False})
print("  title:", jd["title"])
for s in jd["required_skills"]:
    kind = "must " if s["weight"] == 1.0 else "nice "
    print(f"    [{kind}] {s['name']:<10} weight={s['weight']} min_prof={s['min_proficiency']}")
print("  eligibility:", jd["eligibility"])

head("STEP 5 - Explainable match: student vs this internship")
m = call("/ai/match", {"student": {"meta": {"degree": "B.Tech", "branch": "CSE",
                                            "cgpa": 8.1, "grad_year": 2026},
                                   "skills": [{"skill_id": k, "proficiency": v}
                                              for k, v in STUDENT.items()]},
                       "opportunity": {"opportunity_id": 1, "title": jd["title"],
                                       "required_skills": jd["required_skills"],
                                       "eligibility": jd["eligibility"]}})
print(f"  COMPATIBILITY: {m['compatibility_score']}%   eligible: {m['eligible']}")
for row in m["matched"]:
    print(f"    [OK ] {row['name']:<12} credit={row['credit']}")
for row in m["partial"]:
    print(f"    [!! ] {row['name']:<12} credit={row['credit']} (you={row['your_proficiency']}, need={row['required']})")
for row in m["missing"]:
    print(f"    [XX ] {row['name']:<12} credit=0.0")
e = m["explanation"]
print(f"  why: {e['formula']}  ->  earned {e['earned']} / possible {e['possible']}")

head("STEP 6 - Gap-driven recommendations (course -> project -> assessment)")
gaps = [{"skill_id": r["skill_id"], "weight": r["weight"]}
        for r in m["missing"] + m["partial"]]
rec = call("/ai/recommendations", {"gaps": gaps, "limit": 2,
                                   "opportunities": [{"opportunity_id": 1,
                                                      "title": jd["title"],
                                                      "required_skills": jd["required_skills"]}]})
for step in rec["roadmap"]:
    chain = " -> ".join(f"{c['type']}: {c['title']}" for c in step["chain"])
    print(f"  {step['name']:<12}: {chain}")
print("  Top internships to close gaps:")
for i in rec.get("internships", []):
    print(f"    - {i['title']} (score {i['score']}) {i['reason']}")

print("\nDONE - all 6 AI behaviours executed against", BASE)
```

##### `samples/01_normalize.json`
```json
{"terms": ["ReactJS", "react.js", "k8s", "node.js", "kubernets", "quantum cobol"]}
```

##### `samples/02_resume_extract.json`
```json
{
  "resume_text": "EDUCATION\nB.Tech Computer Science, 2026 batch, CGPA: 8.1\nSKILLS\nLinux, Git, Networking, Docker, Kubernetes, AWS\nEXPERIENCE\nCloud Intern, XYZ - Jun 2024 - Aug 2024\nPROJECTS\nCampus Portal - deployed with docker\nCERTIFICATIONS\nAWS Cloud Practitioner (2025)\n",
  "use_llm": false
}
```

##### `samples/03_opportunity_extract.json`
```json
{
  "jd_text": "DevOps Intern\nMust have Docker and Linux. Must have CI/CD. Good to have Terraform.\nKubernetes and AWS required with basic proficiency.\nEligibility: B.Tech CSE 2026 batch, CGPA 7.0+\n",
  "use_llm": false
}
```

##### `samples/04_match.json`
```json
{
  "student": {
    "student_id": 1,
    "meta": {"degree": "B.Tech", "branch": "CSE", "cgpa": 8.1, "grad_year": 2026},
    "skills": [
      {"skill_id": "sk_linux", "proficiency": 0.8},
      {"skill_id": "sk_git", "proficiency": 0.6},
      {"skill_id": "sk_networking", "proficiency": 0.5},
      {"skill_id": "sk_docker", "proficiency": 0.3},
      {"skill_id": "sk_kubernetes", "proficiency": 0.25},
      {"skill_id": "sk_aws", "proficiency": 0.22}
    ]
  },
  "opportunity": {
    "opportunity_id": 1,
    "title": "DevOps Intern",
    "required_skills": [
      {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_aws", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3}
    ],
    "eligibility": {"degrees": ["B.Tech"], "branches": ["CSE"], "min_cgpa": 7.0, "grad_years": [2026]}
  }
}
```

##### `samples/05_matches_batch.json`
```json
{
  "student": {
    "student_id": 1,
    "meta": {"degree": "B.Tech", "branch": "CSE", "cgpa": 8.1, "grad_year": 2026},
    "skills": [
      {"skill_id": "sk_linux", "proficiency": 0.8},
      {"skill_id": "sk_git", "proficiency": 0.6},
      {"skill_id": "sk_networking", "proficiency": 0.5},
      {"skill_id": "sk_docker", "proficiency": 0.3},
      {"skill_id": "sk_kubernetes", "proficiency": 0.25},
      {"skill_id": "sk_aws", "proficiency": 0.22}
    ]
  },
  "opportunities": [
    {
      "opportunity_id": 2,
      "title": "React Intern",
      "required_skills": [
        {"skill_id": "sk_react", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_js", "weight": 1.0, "min_proficiency": 0.3},
        {"skill_id": "sk_css", "weight": 0.5, "min_proficiency": 0.3}
      ],
      "eligibility": null
    },
    {
      "opportunity_id": 1,
      "title": "DevOps Intern",
      "required_skills": [
        {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_aws", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3}
      ],
      "eligibility": {"degrees": ["B.Tech"], "branches": ["CSE"], "min_cgpa": 7.0, "grad_years": [2026]}
    }
  ]
}
```

##### `samples/06_skill_gap.json`
```json
{
  "student": {
    "student_id": 1,
    "skills": [
      {"skill_id": "sk_linux", "proficiency": 0.8},
      {"skill_id": "sk_git", "proficiency": 0.6},
      {"skill_id": "sk_networking", "proficiency": 0.5},
      {"skill_id": "sk_docker", "proficiency": 0.3},
      {"skill_id": "sk_kubernetes", "proficiency": 0.25},
      {"skill_id": "sk_aws", "proficiency": 0.22}
    ]
  },
  "role_requirements": [
    {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_networking", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_aws", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5}
  ]
}
```

##### `samples/07_recommendations.json`
```json
{
  "gaps": [
    {"skill_id": "sk_ci_cd", "weight": 1.0},
    {"skill_id": "sk_docker", "weight": 1.0},
    {"skill_id": "sk_kubernetes", "weight": 1.0},
    {"skill_id": "sk_aws", "weight": 1.0},
    {"skill_id": "sk_terraform", "weight": 0.5}
  ],
  "types": ["course", "project", "internship", "assessment"],
  "limit": 2,
  "opportunities": [
    {
      "opportunity_id": 1,
      "title": "DevOps Intern",
      "required_skills": [
        {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_aws", "weight": 1.0, "min_proficiency": 0.5},
        {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3}
      ]
    }
  ]
}
```

##### `samples/run_all.sh`
```bash
#!/usr/bin/env bash
# Quick-reference runner: fires every sample payload at the running service
# and prints a condensed result. Usage:  bash samples/run_all.sh [base_url]
set -e
BASE=${1:-http://localhost:8000}
cd "$(dirname "$0")/.."
P() { curl -s -X POST "$BASE$1" -H 'Content-Type: application/json' -d @"$2"; }

echo "== GET  /ai/skills"
curl -s "$BASE/ai/skills" | python3 -c "import json,sys; d=json.load(sys.stdin); print('  ', len(d), 'skills; first three:', [s['name'] for s in d[:3]])"

echo "== POST /ai/skills/normalize"
P /ai/skills/normalize samples/01_normalize.json | python3 -c "import json,sys; [print('  ', r['input'], '->', r['name'], '('+r['method']+')') for r in json.load(sys.stdin)['results']]"

echo "== POST /ai/resume/extract"
P /ai/resume/extract samples/02_resume_extract.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   skills:', [s['name'] for s in j['skills']]); print('   months:', j['experience']['total_months'], '| edu:', j['education'], '| source:', j['extraction_source'])"

echo "== POST /ai/opportunity/extract"
P /ai/opportunity/extract samples/03_opportunity_extract.json | python3 -c "import json,sys; j=json.load(sys.stdin); [print('  ', 'must ' if s['weight']==1.0 else 'nice ', s['name'], 'w='+str(s['weight']), 'min='+str(s['min_proficiency'])) for s in j['required_skills']]; print('   eligibility:', j['eligibility'])"

echo "== POST /ai/match"
P /ai/match samples/04_match.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   score:', j['compatibility_score'], '| eligible:', j['eligible']); print('   OK :', [m['name'] for m in j['matched']]); print('   !! :', [m['name'] for m in j['partial']]); print('   XX :', [m['name'] for m in j['missing']]); print('   why:', j['explanation']['earned'], '/', j['explanation']['possible'])"

echo "== POST /ai/matches/batch (ranked)"
P /ai/matches/batch samples/05_matches_batch.json | python3 -c "import json,sys; [print('  ', r['compatibility_score'], '-', r['title']) for r in json.load(sys.stdin)['results']]"

echo "== POST /ai/skill-gap"
P /ai/skill-gap samples/06_skill_gap.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   readiness:', j['readiness']); [print('   -', g['name'], g['severity'], '+'+str(g['recoverable_points'])+' pts') for g in j['priority_gaps']]"

echo "== POST /ai/recommendations"
P /ai/recommendations samples/07_recommendations.json | python3 -c "import json,sys; j=json.load(sys.stdin); [print('  ', s['name'], ':', ' -> '.join(c['type']+': '+c['title'] for c in s['chain'])) for s in j['roadmap'][:3]]; print('   internships:', [(i['title'], i['score']) for i in j.get('internships', [])])"

echo "ALL ENDPOINTS OK"
```

##### `README.md`
```markdown
# Progress — AI Intelligence Microservice (owner: AI module)

Stateless FastAPI service. No DB access. The main backend hydrates payloads from
PostgreSQL and calls these endpoints; the LLM is optional (works 100% without a key).

## Setup
```bash
cd ai-intelligence
python3 -m venv .venv && source .venv/bin/activate   # optional but recommended
pip install -r requirements.txt
python3 -m pytest tests/ -q                          # must show 17 passed
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Interactive docs: http://localhost:8000/docs

## Optional LLM enhancement
```bash
export OPENAI_API_KEY=sk-...          # any OpenAI-compatible gateway:
export OPENAI_BASE_URL=https://...    # (default https://api.openai.com/v1)
export LLM_MODEL=gpt-4o-mini
```
Without a key every endpoint still works (dictionary layer), responses carry
`"extraction_source": "dictionary"`.

## Endpoints
| Method & path | Purpose |
|---|---|
| GET  /ai/skills | taxonomy (canonical names, categories, aliases) |
| POST /ai/skills/normalize | any spelling -> ONE canonical skill |
| POST /ai/resume/extract | resume text -> skills/exp/certs/projects/education |
| POST /ai/opportunity/extract | JD text -> weighted required skills + eligibility |
| POST /ai/match | explainable compatibility score (matched/partial/missing) |
| POST /ai/matches/batch | rank many opportunities for one student |
| POST /ai/skill-gap | role readiness % + priority gaps |
| POST /ai/recommendations | gap -> courses/projects/assessments/internships + roadmap |

See INTEGRATION.md for the contracts the backend / UI / DB / security owners need.
```

##### `QUICK_REFERENCE.md`
```markdown
# QUICK REFERENCE — Progress AI Intelligence (all bodies copy-paste ready)

Use in Swagger: open `/docs` → pick endpoint → **Try it out** → paste body → **Execute**.
Use in terminal: `bash samples/run_all.sh` (fires all saved samples, prints condensed results).
Saved bodies: `samples/01_normalize.json` … `samples/07_recommendations.json`.

---

## 0. GET /ai/skills
No body. → 36 canonical skills with categories + aliases (feeds UI autocomplete).
Expected: `36 skills; first three: ['Linux', 'Git', 'Computer Networks']`

## 1. POST /ai/skills/normalize — many spellings → ONE official name
```json
{"terms": ["ReactJS", "react.js", "k8s", "node.js", "kubernets", "quantum cobol"]}
```
Expected:
```
ReactJS -> React (alias)      react.js -> React (alias)      k8s -> Kubernetes (alias)
node.js -> Node.js (exact)    kubernets -> Kubernetes (fuzzy)  quantum cobol -> null (unmapped)
```

## 2. POST /ai/resume/extract — resume text → clean structured data
```json
{
  "resume_text": "EDUCATION\nB.Tech Computer Science, 2026 batch, CGPA: 8.1\nSKILLS\nLinux, Git, Networking, Docker, Kubernetes, AWS\nEXPERIENCE\nCloud Intern, XYZ - Jun 2024 - Aug 2024\nPROJECTS\nCampus Portal - deployed with docker\nCERTIFICATIONS\nAWS Cloud Practitioner (2025)\n",
  "use_llm": false
}
```
Expected: skills `[AWS, Docker, Git, Kubernetes, Linux, Computer Networks]`, months `3`,
education `{B.Tech, CSE, 2026, 8.1}`, certs `[AWS Cloud Practitioner (2025)]`,
projects `[Campus Portal - deployed with docker]`, source `dictionary`.
(Set `use_llm: true` + OPENAI_API_KEY to add the LLM enhancement layer.)

## 3. POST /ai/opportunity/extract — JD → weighted requirements + eligibility
```json
{
  "jd_text": "DevOps Intern\nMust have Docker and Linux. Must have CI/CD. Good to have Terraform.\nKubernetes and AWS required with basic proficiency.\nEligibility: B.Tech CSE 2026 batch, CGPA 7.0+\n",
  "use_llm": false
}
```
Expected: must(weight 1.0, min 0.5): AWS, CI/CD, Docker, Kubernetes, Linux ·
nice(weight 0.5, min 0.3): Terraform ·
eligibility `{degrees:[B.Tech], branches:[CSE], min_cgpa:7.0, grad_years:[2026]}`.

## 4. POST /ai/match — explainable compatibility (the ✓ / ⚠ /  card)
```json
{
  "student": {
    "student_id": 1,
    "meta": {"degree": "B.Tech", "branch": "CSE", "cgpa": 8.1, "grad_year": 2026},
    "skills": [
      {"skill_id": "sk_linux", "proficiency": 0.8},
      {"skill_id": "sk_git", "proficiency": 0.6},
      {"skill_id": "sk_networking", "proficiency": 0.5},
      {"skill_id": "sk_docker", "proficiency": 0.3},
      {"skill_id": "sk_kubernetes", "proficiency": 0.25},
      {"skill_id": "sk_aws", "proficiency": 0.22}
    ]
  },
  "opportunity": {
    "opportunity_id": 1,
    "title": "DevOps Intern",
    "required_skills": [
      {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_aws", "weight": 1.0, "min_proficiency": 0.5},
      {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3}
    ],
    "eligibility": {"degrees": ["B.Tech"], "branches": ["CSE"], "min_cgpa": 7.0, "grad_years": [2026]}
  }
}
```
Expected: `score 46.2 | eligible true` · ✓ Linux · ⚠ Docker, Kubernetes, AWS ·
🔴 CI/CD, Terraform · explanation `earned 2.54 / possible 5.5`.

## 5. POST /ai/matches/batch — ranked opportunity list (same student, N opportunities)
Body = `{"student": <same as above>, "opportunities": [ <React Intern: react w1 .5, js w1 .3, css .5 .3, eligibility null>, <DevOps Intern as above> ]}`
(full body saved in `samples/05_matches_batch.json`)
Expected ranking: `46.2 DevOps Intern` then `0.0 React Intern`.

## 6. POST /ai/skill-gap — role readiness % + priority gaps (the 61% slide)
```json
{
  "student": {
    "student_id": 1,
    "skills": [
      {"skill_id": "sk_linux", "proficiency": 0.8},
      {"skill_id": "sk_git", "proficiency": 0.6},
      {"skill_id": "sk_networking", "proficiency": 0.5},
      {"skill_id": "sk_docker", "proficiency": 0.3},
      {"skill_id": "sk_kubernetes", "proficiency": 0.25},
      {"skill_id": "sk_aws", "proficiency": 0.22}
    ]
  },
  "role_requirements": [
    {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_git", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_networking", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
    {"skill_id": "sk_aws", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3},
    {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5}
  ]
}
```
Expected: `readiness 61.0` · priority gaps: CI/CD absent +15.4 pts, Terraform absent +7.7,
Kubernetes partial +7.7, Docker partial +6.2, AWS partial +2.1.

## 7. POST /ai/recommendations — gap → course → project → assessment + internships
```json
{
  "gaps": [
    {"skill_id": "sk_ci_cd", "weight": 1.0},
    {"skill_id": "sk_docker", "weight": 1.0},
    {"skill_id": "sk_kubernetes", "weight": 1.0},
    {"skill_id": "sk_aws", "weight": 1.0},
    {"skill_id": "sk_terraform", "weight": 0.5}
  ],
  "types": ["course", "project", "internship", "assessment"],
  "limit": 2,
  "opportunities": [
    {"opportunity_id": 1, "title": "DevOps Intern",
     "required_skills": [
       {"skill_id": "sk_linux", "weight": 1.0, "min_proficiency": 0.5},
       {"skill_id": "sk_docker", "weight": 1.0, "min_proficiency": 0.5},
       {"skill_id": "sk_ci_cd", "weight": 1.0, "min_proficiency": 0.5},
       {"skill_id": "sk_kubernetes", "weight": 1.0, "min_proficiency": 0.5},
       {"skill_id": "sk_aws", "weight": 1.0, "min_proficiency": 0.5},
       {"skill_id": "sk_terraform", "weight": 0.5, "min_proficiency": 0.3}]}
  ]
}
```
Expected: per-gap chains e.g. `CI/CD: course: CI/CD with GitHub Actions -> project: Build a CI
Pipeline for a Node App -> assessment: CI/CD Assessment` · internships `[("DevOps Intern", 4.5)]`.

---

### Field cheat-sheet
- `proficiency` 0..1 (beginner .25 / intermediate .5 / good .75 / expert 1)
- `weight` 1.0 must-have / 0.5 nice-to-have · `min_proficiency` = bar to clear for full credit
- status: `matched` ✓ credit=1 · `partial` ⚠ 0<credit<1 · `missing` 🔴 credit=0
- score = 100 × Σ(weight×credit) / Σ(weight) — always shipped with `explanation`
- unmapped terms are never scored; `use_llm:false` = pure deterministic layer
```

##### `INTEGRATION.md`
```markdown
# Integration Contracts — who builds what against the AI service

## 1) DB owner (PostgreSQL) — tables the backend must fill/read around AI calls
```sql
skills(id text pk, name text unique, category text, aliases jsonb)          -- seed from skill_intelligence/taxonomy/skills.json
student_skills(student_id fk, skill_id fk, proficiency real check (proficiency between 0 and 1),
               source text,          -- 'resume' | 'assessment' | 'manual'
               verification text,    -- 'SELF_DECLARED' | 'ASSESSMENT_VERIFIED' | ... (portfolio ladder)
               primary key (student_id, skill_id))
opportunity_skills(opportunity_id fk, skill_id fk, weight real, min_proficiency real)
career_role_skills(role_id fk, skill_id fk, weight real, min_proficiency real)
course_skills(course_id fk, skill_id fk)
project_skills(project_id fk, skill_id fk)
documents(id pk, owner_id fk, doc_type text, raw_payload jsonb, created_at timestamptz)  -- store extract results verbatim
students(id pk, degree text, branch text, cgpa real, grad_year int, location text)      -- feeds "student_meta"
```
Rules: proficiency is ALWAYS 0..1 (levels: beginner .25 / intermediate .5 / good .75 / expert 1).
weight: 1.0 must-have, 0.5 nice-to-have. Resume-extracted rows start at verification='SELF_DECLARED'.

## 2) Backend owner — wrapper endpoints (auth + persistence live HERE, not in AI service)
- `POST /api/resume/upload` (multipart) -> extract text (pypdf/python-docx) -> call AI `/ai/resume/extract`
  -> save `documents.raw_payload` + `student_skills(source='resume', verification='SELF_DECLARED')`
  -> return the extract so UI can show a confirm/edit screen.
- `POST /api/student/resume/confirm` -> apply student's edits to student_skills.
- `POST /api/opportunities` -> call AI `/ai/opportunity/extract` -> save opportunity + opportunity_skills + eligibility jsonb.
- `GET  /api/matches` -> build student vector from student_skills + meta; open opportunities from
  opportunity_skills; call AI `/ai/matches/batch`; return ranked list.
- `POST /api/matches/{id}` -> single `/ai/match` (explainable card).
- `GET  /api/recommendations` -> gaps from latest `/ai/skill-gap` (or top match's missing list)
  -> call AI `/ai/recommendations`.
AI service is called server-to-server only; never expose it publicly without the security owner's rate limits.

## 3) UI owner — screens and the exact JSON fields to render
- Resume upload screen: show `skills[]` chips (name + method), `unmapped_terms[]` as "not in taxonomy - review",
  education/experience/certs preview; confirm button hits backend confirm endpoint.
- Opportunity form: paste JD -> preview `required_skills[]` chips with weight badge (must/nice) + eligibility summary.
- Match card: `compatibility_score` ring; `matched[]` as checkmarks, `partial[]` as warning, `missing[]` as red;
  tooltip/accordion shows `explanation.formula`, `earned/possible`, per-row credit. NEVER show a bare score.
- Opportunity list: score badge from `/api/matches` (already ranked).
- Development path: `roadmap[]` (per gap: course -> project -> assessment chain) + top-3 `courses/projects/internships`
  with their `reason` strings.
- Skill picker/autocomplete: `GET /ai/skills` (via backend proxy).

## 4) Security owner — checklist touching this service
- CORS in app/main.py is `*` for dev ONLY - replace with the web app origin before staging.
- Add rate limiting + auth (JWT verify) at the MAIN BACKEND; keep AI service internal (network-private).
- Extract endpoints accept raw text: enforce max body size (e.g. 1 MB) at backend proxy.
- documents.raw_payload may contain PII - apply the project's document access-control rules.
- LLM key lives in secret manager (env var only); service logs must not print resume text.

## 5) Frozen rules (do not change without team sync)
- Score formula: `100 * sum(weight x credit) / sum(weight)`, `credit = min(1, proficiency/min_proficiency)`.
- Priority gaps ordered by recoverable points `weight x (1 - credit)`.
- Unmapped terms are NEVER scored.
- Every score response includes its explanation block.
- AI service stays stateless (no DB, no files written at runtime).
```
