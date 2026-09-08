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
