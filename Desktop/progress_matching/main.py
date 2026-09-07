"""
Progress Matching Engine - All 8 Problems
1. Semantic skill matching
2. Student–opportunity compatibility
3. Explainable match results
4. Skill-gap explanation
5. Career recommendations
6. Learning recommendations
7. Project recommendations
8. Internship recommendations
"""

from services.embeddings import semantic_skill_match, batch_semantic_match
from services.compatibility import calculate_compatibility
from services.explain import generate_match_explanation
from services.skill_gap import analyze_skill_gap
from services.career import recommend_careers
from services.learning import recommend_learning
from services.project import recommend_projects
from services.internship import recommend_internships
import json


# ====================== SAMPLE DATA (for testing) ======================

sample_student = {
    "student_id": "stu_001",
    "skills": [
        {"name": "Linux", "proficiency": 85, "verification_level": "project_verified"},
        {"name": "Git", "proficiency": 90, "verification_level": "assessment_verified"},
        {"name": "Networking", "proficiency": 70, "verification_level": "self_declared"},
        {"name": "Docker", "proficiency": 55, "verification_level": "self_declared"},
        {"name": "Python", "proficiency": 80, "verification_level": "project_verified"}
    ],
    "career_goals": [
        {"role_id": "devops", "role_name": "DevOps Engineer", "priority": 1}
    ],
    "eligibility": {
        "location": "Delhi",
        "degree": "B.Tech",
        "graduation_year": 2025,
        "years_experience": 0.5
    }
}

sample_opportunity = {
    "opportunity_id": "int_101",
    "type": "internship",
    "title": "DevOps Intern",
    "required_skills": [
        {"name": "Linux", "min_proficiency": 70, "weight": 0.20, "importance": "must_have"},
        {"name": "Git", "min_proficiency": 60, "weight": 0.15, "importance": "must_have"},
        {"name": "Docker", "min_proficiency": 70, "weight": 0.25, "importance": "must_have"},
        {"name": "Kubernetes", "min_proficiency": 60, "weight": 0.25, "importance": "must_have"},
        {"name": "AWS", "min_proficiency": 50, "weight": 0.15, "importance": "nice_to_have"}
    ],
    "eligibility": {
        "locations": ["Delhi", "Remote", "Bangalore"],
        "min_degree": "B.Tech"
    },
    "career_roles": ["DevOps Engineer", "Cloud Engineer"]
}

sample_opportunity_2 = {
    "opportunity_id": "int_102",
    "type": "internship",
    "title": "Cloud Support Intern",
    "required_skills": [
        {"name": "Linux", "min_proficiency": 60, "weight": 0.30, "importance": "must_have"},
        {"name": "Networking", "min_proficiency": 60, "weight": 0.30, "importance": "must_have"},
        {"name": "AWS", "min_proficiency": 40, "weight": 0.20, "importance": "nice_to_have"},
        {"name": "Python", "min_proficiency": 50, "weight": 0.20, "importance": "nice_to_have"}
    ],
    "eligibility": {
        "locations": ["Delhi", "Remote"],
        "min_degree": "B.Tech"
    },
    "career_roles": ["Cloud Engineer", "Support Engineer"]
}

sample_opportunities = [sample_opportunity, sample_opportunity_2]

sample_required_for_role = [
    {"name": "Linux", "min_proficiency": 70},
    {"name": "Git", "min_proficiency": 60},
    {"name": "Docker", "min_proficiency": 75},
    {"name": "Kubernetes", "min_proficiency": 70},
    {"name": "AWS", "min_proficiency": 60},
    {"name": "CI/CD", "min_proficiency": 65},
    {"name": "Terraform", "min_proficiency": 50}
]


# ====================== DEMO FUNCTIONS ======================

def demo_semantic_matching():
    print("\n" + "="*60)
    print("1. SEMANTIC SKILL MATCHING")
    print("="*60)
    result = semantic_skill_match("Docker", "Containerization")
    print(json.dumps(result, indent=2))
    print("\nBatch example:")
    batch = batch_semantic_match(
        ["Linux", "Git", "Docker", "Python"],
        ["Kubernetes", "Version Control", "Containerization", "AWS"]
    )
    print(json.dumps(batch, indent=2))


def demo_compatibility():
    print("\n" + "="*60)
    print("2. STUDENT–OPPORTUNITY COMPATIBILITY")
    print("="*60)
    result = calculate_compatibility(sample_student, sample_opportunity)
    print(json.dumps(result, indent=2))
    return result


def demo_explanation(match_result):
    print("\n" + "="*60)
    print("3. EXPLAINABLE MATCH RESULTS")
    print("="*60)
    explanation = generate_match_explanation(match_result)
    print(json.dumps(explanation, indent=2))


def demo_skill_gap():
    print("\n" + "="*60)
    print("4. SKILL-GAP EXPLANATION")
    print("="*60)
    result = analyze_skill_gap(
        student_skills=sample_student["skills"],
        target_role="DevOps Engineer",
        required_skills=sample_required_for_role
    )
    print(json.dumps(result, indent=2))
    return result


def demo_career_recommendations():
    print("\n" + "="*60)
    print("5. CAREER RECOMMENDATIONS")
    print("="*60)
    result = recommend_careers(sample_student)
    print(json.dumps(result, indent=2))


def demo_learning_recommendations(skill_gap_result):
    print("\n" + "="*60)
    print("6. LEARNING RECOMMENDATIONS")
    print("="*60)
    result = recommend_learning(skill_gap_result["skill_gaps"])
    print(json.dumps(result, indent=2))


def demo_project_recommendations(skill_gap_result):
    print("\n" + "="*60)
    print("7. PROJECT RECOMMENDATIONS")
    print("="*60)
    result = recommend_projects(skill_gap_result["skill_gaps"])
    print(json.dumps(result, indent=2))


def demo_internship_recommendations():
    print("\n" + "="*60)
    print("8. INTERNSHIP RECOMMENDATIONS")
    print("="*60)
    result = recommend_internships(sample_student, sample_opportunities)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    print("Progress Matching Engine - All 8 Problems")
    print("Make sure you have set GEMINI_API_KEY in .env file")

    demo_semantic_matching()
    match_result = demo_compatibility()
    demo_explanation(match_result)
    skill_gap_result = demo_skill_gap()
    demo_career_recommendations()
    demo_learning_recommendations(skill_gap_result)
    demo_project_recommendations(skill_gap_result)
    demo_internship_recommendations()

    print("\nAll 8 core problems ran successfully.")
