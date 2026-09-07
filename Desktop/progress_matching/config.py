import os
import sys
from dotenv import load_dotenv

load_dotenv()

# Gemini Configuration
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
EMBEDDING_MODEL = "gemini-embedding-001"
LLM_MODEL = "gemini-3.6-flash"

if not GEMINI_API_KEY:
    sys.exit(
        "ERROR: GEMINI_API_KEY is not set.\n"
        "Add it to your .env file as: GEMINI_API_KEY=your_key_here\n"
        "Get a free key at https://aistudio.google.com/apikey"
    )

# Matching Configuration
SEMANTIC_THRESHOLD = 0.78
DEFAULT_WEIGHTS = {
    "skill_fit": 0.55,
    "eligibility_fit": 0.20,
    "goal_alignment": 0.15,
    "verification_boost": 0.10
}

# Verification level scores
VERIFICATION_SCORES = {
    "self_declared": 0.2,
    "assessment_verified": 0.5,
    "project_verified": 0.7,
    "certification_verified": 0.85,
    "industry_verified": 1.0
}

# Retry configuration (used by embeddings.py and utils/helpers.py)
MAX_RETRY_ATTEMPTS = 4
RETRY_MIN_WAIT = 2
RETRY_MAX_WAIT = 15
