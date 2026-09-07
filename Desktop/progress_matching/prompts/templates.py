import json

EXPLAIN_MATCH_TEMPLATE = """You are a career advisor.
Explain the match result clearly using only the data provided.
Do not invent anything.
Return only JSON in this exact format:
{{
  "explanation": "clear paragraph",
  "matched_skills": ["list"],
  "partial_skills": ["list"],
  "missing_skills": ["list"],
  "advice": "one short advice"
}}

Match Data:
{match_data}
"""

SKILL_GAP_TEMPLATE = """You are a skill gap analysis expert.
Compare the student skills with the target role requirements.
Return only JSON in this exact format:
{{
  "target_role": "role name",
  "readiness_score": 0-100,
  "matched_skills": ["list"],
  "skill_gaps": [
    {{
      "skill": "skill name",
      "severity": "High/Medium/Low",
      "explanation": "short explanation"
    }}
  ],
  "summary": "short summary"
}}

Student Skills: {student_skills}
Target Role: {target_role}
Required Skills: {required_skills}
"""

CAREER_RECOMMENDATION_TEMPLATE = """You are an expert career counselor.
Based on the student's skill profile, recommend the top 5 most suitable career roles.
Only use the data provided. Do not invent skills the student does not have.
Return only JSON in this exact format:
{{
  "recommendations": [
    {{
      "role": "role name",
      "match_score": 0-100,
      "reason": "why this role suits the student",
      "missing_skills": ["list"]
    }}
  ]
}}

Student Profile:
{student_profile}
"""

LEARNING_RECOMMENDATION_TEMPLATE = """You are a learning path expert.
Based on the student's skill gaps below, recommend the best learning resources (courses or certifications) to close them.
Prioritize the highest-severity gaps first.
Return only JSON in this exact format:
{{
  "recommendations": [
    {{
      "title": "course or certification name",
      "type": "Course/Certification",
      "skills_covered": ["list"],
      "priority": "High/Medium/Low",
      "reason": "why this is recommended"
    }}
  ]
}}

Skill Gaps:
{skill_gaps}
"""

PROJECT_RECOMMENDATION_TEMPLATE = """You are a practical learning expert.
Based on the student's skill gaps below, recommend hands-on projects that will help close those gaps and can be verified afterward.
Return only JSON in this exact format:
{{
  "recommendations": [
    {{
      "project_title": "project name",
      "skills_practiced": ["list"],
      "difficulty": "Beginner/Intermediate/Advanced",
      "reason": "why this project helps",
      "expected_outcome": "what skill gets verified"
    }}
  ]
}}

Skill Gaps:
{skill_gaps}
"""

INTERNSHIP_RECOMMENDATION_TEMPLATE = """You are an internship matching expert.
Given the student profile and the pre-scored list of internships below (already ranked by a compatibility formula), review and explain the best matches.
Do not change the compatibility scores. Only add reasoning and highlight what skills each internship would help verify.
Return only JSON in this exact format:
{{
  "recommendations": [
    {{
      "opportunity_id": "id",
      "title": "internship title",
      "compatibility_score": 0-100,
      "reason": "why recommended",
      "gaps_closed": ["list"]
    }}
  ]
}}

Student Profile:
{student_profile}

Scored Internships:
{scored_internships}
"""


def build_explain_prompt(match_data: dict) -> str:
    return EXPLAIN_MATCH_TEMPLATE.format(match_data=json.dumps(match_data, indent=2))


def build_skill_gap_prompt(student_skills: list, target_role: str, required_skills: list) -> str:
    return SKILL_GAP_TEMPLATE.format(
        student_skills=json.dumps(student_skills, indent=2),
        target_role=target_role,
        required_skills=json.dumps(required_skills, indent=2)
    )


def build_career_prompt(student_profile: dict) -> str:
    return CAREER_RECOMMENDATION_TEMPLATE.format(
        student_profile=json.dumps(student_profile, indent=2)
    )


def build_learning_prompt(skill_gaps: list) -> str:
    return LEARNING_RECOMMENDATION_TEMPLATE.format(
        skill_gaps=json.dumps(skill_gaps, indent=2)
    )


def build_project_prompt(skill_gaps: list) -> str:
    return PROJECT_RECOMMENDATION_TEMPLATE.format(
        skill_gaps=json.dumps(skill_gaps, indent=2)
    )


def build_internship_prompt(student_profile: dict, scored_internships: list) -> str:
    return INTERNSHIP_RECOMMENDATION_TEMPLATE.format(
        student_profile=json.dumps(student_profile, indent=2),
        scored_internships=json.dumps(scored_internships, indent=2)
    )
