"""Progress AI Intelligence microservice (FastAPI). Stateless: no DB access here.
The main backend hydrates payloads from PostgreSQL and calls these endpoints."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import (BatchMatchRequest, ExtractJDRequest, ExtractResumeRequest,
                         MatchRequest, NormalizeRequest, RecommendRequest, SkillGapRequest)
from internship_intelligence.compatibility import compatibility
from internship_intelligence.extraction import parse_jd
from internship_intelligence.ranking import rank
from internship_intelligence.recommendation import recommend
from skill_intelligence.extraction import parse_resume
from skill_intelligence.normalization import normalize_many
from skill_intelligence.priority_gap import prioritize
from skill_intelligence.readiness import readiness
from skill_intelligence.taxonomy import all_skills

app = FastAPI(title="Progress AI Intelligence", version="1.0.0")

# NOTE for security owner: tighten origins to the web app's domain before production.
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])


def _student_skills(student) -> dict:
    return {s.skill_id: s.proficiency for s in student.skills}


def _meta(student):
    return student.meta.model_dump() if student.meta else None


def _opp_dict(opp) -> dict:
    d = opp.model_dump()
    return d


@app.get("/")
def root():
    return {"service": "Progress AI Intelligence", "version": "1.0.0",
            "endpoints": ["/ai/skills", "/ai/skills/normalize", "/ai/resume/extract",
                          "/ai/opportunity/extract", "/ai/match", "/ai/matches/batch",
                          "/ai/skill-gap", "/ai/recommendations"]}


@app.get("/ai/skills")
def get_skills():
    return all_skills()


@app.post("/ai/skills/normalize")
def post_normalize(req: NormalizeRequest):
    return {"results": normalize_many(req.terms)}


@app.post("/ai/resume/extract")
def post_resume(req: ExtractResumeRequest):
    return parse_resume(req.resume_text, use_llm=req.use_llm)


@app.post("/ai/opportunity/extract")
def post_jd(req: ExtractJDRequest):
    return parse_jd(req.jd_text, use_llm=req.use_llm)


@app.post("/ai/match")
def post_match(req: MatchRequest):
    return compatibility(_student_skills(req.student), _opp_dict(req.opportunity),
                         _meta(req.student))


@app.post("/ai/matches/batch")
def post_batch(req: BatchMatchRequest):
    results = [compatibility(_student_skills(req.student), _opp_dict(o), _meta(req.student))
               for o in req.opportunities]
    return {"results": rank(results)}


@app.post("/ai/skill-gap")
def post_skill_gap(req: SkillGapRequest):
    res = readiness(_student_skills(req.student),
                    [r.model_dump() for r in req.role_requirements])
    res["priority_gaps"] = prioritize(res["rows"])
    return res


@app.post("/ai/recommendations")
def post_recommend(req: RecommendRequest):
    gaps = [g.model_dump() for g in req.gaps]
    opps = [_opp_dict(o) for o in req.opportunities] if req.opportunities else None
    return recommend(gaps, types=req.types, limit=req.limit, opportunities=opps)
