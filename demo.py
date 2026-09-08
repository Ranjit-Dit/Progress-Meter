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
