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
