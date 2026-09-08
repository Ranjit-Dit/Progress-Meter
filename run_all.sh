#!/usr/bin/env bash
# Quick-reference runner: fires every sample payload at the running service
# and prints a condensed result. Usage:  bash samples/run_all.sh [base_url]
set -e
BASE=${1:-http://localhost:8000}
cd "$(dirname "$0")/.."
P() { curl -s -X POST "$BASE$1" -H 'Content-Type: application/json' -d @"$2"; }

echo "== GET  /ai/skills"
curl -s "$BASE/ai/skills" | python3 -c "import json,sys; d=json.load(sys.stdin); print('  ', len(d), 'skills; first three:', [s['name'] for s in d[:3]])"

echo "== POST /ai/skills/normalize"
P /ai/skills/normalize samples/01_normalize.json | python3 -c "import json,sys; [print('  ', r['input'], '->', r['name'], '('+r['method']+')') for r in json.load(sys.stdin)['results']]"

echo "== POST /ai/resume/extract"
P /ai/resume/extract samples/02_resume_extract.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   skills:', [s['name'] for s in j['skills']]); print('   months:', j['experience']['total_months'], '| edu:', j['education'], '| source:', j['extraction_source'])"

echo "== POST /ai/opportunity/extract"
P /ai/opportunity/extract samples/03_opportunity_extract.json | python3 -c "import json,sys; j=json.load(sys.stdin); [print('  ', 'must ' if s['weight']==1.0 else 'nice ', s['name'], 'w='+str(s['weight']), 'min='+str(s['min_proficiency'])) for s in j['required_skills']]; print('   eligibility:', j['eligibility'])"

echo "== POST /ai/match"
P /ai/match samples/04_match.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   score:', j['compatibility_score'], '| eligible:', j['eligible']); print('   OK :', [m['name'] for m in j['matched']]); print('   !! :', [m['name'] for m in j['partial']]); print('   XX :', [m['name'] for m in j['missing']]); print('   why:', j['explanation']['earned'], '/', j['explanation']['possible'])"

echo "== POST /ai/matches/batch (ranked)"
P /ai/matches/batch samples/05_matches_batch.json | python3 -c "import json,sys; [print('  ', r['compatibility_score'], '-', r['title']) for r in json.load(sys.stdin)['results']]"

echo "== POST /ai/skill-gap"
P /ai/skill-gap samples/06_skill_gap.json | python3 -c "import json,sys; j=json.load(sys.stdin); print('   readiness:', j['readiness']); [print('   -', g['name'], g['severity'], '+'+str(g['recoverable_points'])+' pts') for g in j['priority_gaps']]"

echo "== POST /ai/recommendations"
P /ai/recommendations samples/07_recommendations.json | python3 -c "import json,sys; j=json.load(sys.stdin); [print('  ', s['name'], ':', ' -> '.join(c['type']+': '+c['title'] for c in s['chain'])) for s in j['roadmap'][:3]]; print('   internships:', [(i['title'], i['score']) for i in j.get('internships', [])])"

echo "ALL ENDPOINTS OK"
