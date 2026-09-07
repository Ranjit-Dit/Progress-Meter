"""
Progress Matching Engine - FastAPI Backend
Exposes all 8 core problems as HTTP endpoints.
"""

import logging
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional

from services.embeddings import semantic_skill_match
from services.compatibility import calculate_compatibility
from services.explain import generate_match_explanation
from services.skill_gap import analyze_skill_gap
from services.career import recommend_careers
from services.learning import recommend_learning
from services.project import recommend_projects
from services.internship import recommend_internships
from config import GEMINI_API_KEY

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("progress_matching")

app = FastAPI(
    title="Progress Matching Engine",
    version="1.1",
    description=(
        "AI-powered student-opportunity matching for the Progress platform. "
        "Provides semantic skill matching, compatibility scoring, skill gap analysis, "
        "and personalized recommendations for careers, learning, projects, and internships."
    ),
)

# --- CORS: allows Flutter, React, or any frontend to call this API ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # In production, replace with your actual frontend URLs
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response Models ──────────────────────────────────────

class SkillItem(BaseModel):
    name: str = Field(..., description="Skill name, e.g. 'Python', 'React Native'")
    level: Optional[str] = Field(None, description="beginner / intermediate / advanced")
    verification: Optional[str] = Field("self_declared", description="Verification level")

class GoalItem(BaseModel):
    role: str = Field(..., description="Target role, e.g. 'ML Engineer'")
    priority: Optional[int] = Field(1, ge=1, le=5)

class Student(BaseModel):
    student_id: str
    skills: List[SkillItem] = Field(..., min_length=1, description="At least one skill required")
    career_goals: List[GoalItem] = []
    eligibility: Dict[str, Any] = {}

class Opportunity(BaseModel):
    opportunity_id: str
    type: str = Field(..., description="internship / job / project / course")
    title: str
    required_skills: List[SkillItem] = Field(..., min_length=1)
    eligibility: Dict[str, Any] = {}
    career_roles: List[str] = []

class SemanticMatchRequest(BaseModel):
    student_skill: str = Field(..., examples=["machine learning"])
    required_skill: str = Field(..., examples=["deep learning"])

class MatchRequest(BaseModel):
    student: Student
    opportunity: Opportunity
    include_explanation: bool = Field(False, description="Include AI-generated explanation")

class SkillGapRequest(BaseModel):
    student_skills: List[SkillItem]
    target_role: str = Field(..., examples=["Full Stack Developer"])
    required_skills: List[SkillItem]

class CareerRequest(BaseModel):
    student: Student

class LearningRequest(BaseModel):
    skill_gaps: List[Dict[str, Any]] = Field(..., min_length=1)

class ProjectRequest(BaseModel):
    skill_gaps: List[Dict[str, Any]] = Field(..., min_length=1)

class InternshipRequest(BaseModel):
    student: Student
    opportunities: List[Opportunity] = Field(..., min_length=1)
    top_n: int = Field(5, ge=1, le=20)


# ── Endpoints ──────────────────────────────────────────────────────

@app.get("/", tags=["System"])
def root():
    return {"status": "ok", "service": "Progress Matching Engine", "version": "1.1"}


@app.get("/health", tags=["System"], summary="Health check for main backend")
def health():
    """Returns whether the matching engine and its dependencies are reachable."""
    from google import genai
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        client.models.list()
        gemini_status = "reachable"
    except Exception as e:
        gemini_status = f"unreachable ({e})"
    return {
        "status": "healthy" if gemini_status == "reachable" else "degraded",
        "gemini_api": gemini_status,
    }


@app.post("/match/semantic", tags=["Matching"],
          summary="Compare two skills semantically")
def match_semantic(req: SemanticMatchRequest):
    """Uses embeddings to determine if two skill names are conceptually similar,
    even if they don't match exactly (e.g. 'ML' vs 'machine learning')."""
    try:
        return semantic_skill_match(req.student_skill, req.required_skill)
    except Exception as e:
        logger.error(f"/match/semantic failed: {e}")
        raise HTTPException(status_code=502, detail=f"Matching failed: {e}")


@app.post("/match", tags=["Matching"],
          summary="Full compatibility score: student vs opportunity")
def match(req: MatchRequest):
    """Calculates a weighted compatibility score across skill fit, eligibility,
    goal alignment, and verification boost. Optionally includes an AI explanation."""
    try:
        result = calculate_compatibility(req.student.model_dump(), req.opportunity.model_dump())
        if req.include_explanation:
            result["explanation"] = generate_match_explanation(result)
        return result
    except Exception as e:
        logger.error(f"/match failed: {e}")
        raise HTTPException(status_code=502, detail=f"Compatibility scoring failed: {e}")


@app.post("/skill-gap", tags=["Analysis"],
          summary="Identify missing skills for a target role")
def skill_gap(req: SkillGapRequest):
    """Compares student skills against role requirements and returns gaps with priority."""
    try:
        return analyze_skill_gap(
            [s.model_dump() for s in req.student_skills],
            req.target_role,
            [s.model_dump() for s in req.required_skills],
        )
    except Exception as e:
        logger.error(f"/skill-gap failed: {e}")
        raise HTTPException(status_code=502, detail=f"Skill gap analysis failed: {e}")


@app.post("/recommendations/career", tags=["Recommendations"],
          summary="Suggest career paths for a student")
def career(req: CareerRequest):
    """Uses AI reasoning to recommend career paths based on the student's skills and goals."""
    try:
        return recommend_careers(req.student.model_dump())
    except Exception as e:
        logger.error(f"/recommendations/career failed: {e}")
        raise HTTPException(status_code=502, detail=f"Career recommendation failed: {e}")


@app.post("/recommendations/learning", tags=["Recommendations"],
          summary="Suggest courses and certifications to fill skill gaps")
def learning(req: LearningRequest):
    """Recommends specific, real learning resources for each identified skill gap."""
    try:
        return recommend_learning(req.skill_gaps)
    except Exception as e:
        logger.error(f"/recommendations/learning failed: {e}")
        raise HTTPException(status_code=502, detail=f"Learning recommendation failed: {e}")


@app.post("/recommendations/project", tags=["Recommendations"],
          summary="Suggest hands-on projects to build missing skills")
def project(req: ProjectRequest):
    """Recommends portfolio-worthy projects tailored to the student's skill gaps."""
    try:
        return recommend_projects(req.skill_gaps)
    except Exception as e:
        logger.error(f"/recommendations/project failed: {e}")
        raise HTTPException(status_code=502, detail=f"Project recommendation failed: {e}")


@app.post("/recommendations/internship", tags=["Recommendations"],
          summary="Rank and recommend best-fit internships")
def internship(req: InternshipRequest):
    """Scores all provided opportunities against the student profile and returns the top N."""
    try:
        opportunities = [o.model_dump() for o in req.opportunities]
        return recommend_internships(req.student.model_dump(), opportunities, top_n=req.top_n)
    except Exception as e:
        logger.error(f"/recommendations/internship failed: {e}")
        raise HTTPException(status_code=502, detail=f"Internship recommendation failed: {e}")
