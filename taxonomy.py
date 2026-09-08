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
