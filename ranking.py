"""Rank opportunities: score desc, tie-break fewer missing must-haves, then stable id."""


def rank(results: list) -> list:
    def key(r):
        missing_must = sum(1 for m in r.get("missing", []) if m.get("weight", 0) >= 1.0)
        return (-r.get("compatibility_score", 0.0), missing_must,
                str(r.get("opportunity_id")))
    return sorted(results, key=key)
