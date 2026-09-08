"""Frozen request/response contracts. UI + backend + DB teammates build against these."""
from typing import Optional

from pydantic import BaseModel, Field


class StudentSkill(BaseModel):
    skill_id: str
    proficiency: float = Field(ge=0, le=1)


class StudentMeta(BaseModel):
    degree: Optional[str] = None
    branch: Optional[str] = None
    cgpa: Optional[float] = None
    grad_year: Optional[int] = None
    location: Optional[str] = None


class Student(BaseModel):
    student_id: Optional[int] = None
    skills: list[StudentSkill] = []
    meta: Optional[StudentMeta] = None


class RequiredSkill(BaseModel):
    skill_id: str
    weight: float = 1.0
    min_proficiency: float = 0.5


class Eligibility(BaseModel):
    degrees: Optional[list[str]] = None
    branches: Optional[list[str]] = None
    min_cgpa: Optional[float] = None
    grad_years: Optional[list[int]] = None
    location: Optional[str] = None


class Opportunity(BaseModel):
    opportunity_id: Optional[int] = None
    title: Optional[str] = None
    required_skills: list[RequiredSkill] = []
    eligibility: Optional[Eligibility] = None


class MatchRequest(BaseModel):
    student: Student
    opportunity: Opportunity


class BatchMatchRequest(BaseModel):
    student: Student
    opportunities: list[Opportunity] = []


class SkillGapRequest(BaseModel):
    student: Student
    role_requirements: list[RequiredSkill] = []


class NormalizeRequest(BaseModel):
    terms: list[str]


class ExtractResumeRequest(BaseModel):
    resume_text: str
    use_llm: bool = True


class ExtractJDRequest(BaseModel):
    jd_text: str
    use_llm: bool = True


class GapItem(BaseModel):
    skill_id: str
    weight: float = 1.0


class RecommendRequest(BaseModel):
    gaps: list[GapItem]
    types: Optional[list[str]] = None
    limit: int = 3
    opportunities: Optional[list[Opportunity]] = None
