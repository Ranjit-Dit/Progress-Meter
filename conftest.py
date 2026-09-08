import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
os.environ.pop("OPENAI_API_KEY", None)  # tests always run the deterministic path
