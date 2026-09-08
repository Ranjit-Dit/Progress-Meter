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
