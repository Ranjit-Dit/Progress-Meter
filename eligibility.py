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
