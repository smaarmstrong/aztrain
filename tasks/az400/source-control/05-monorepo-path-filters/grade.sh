#!/usr/bin/env bash
# Parse ci.yml with the repo's stdlib yamlmini loader and assert the monorepo
# trigger is scoped to main + a paths filter, with one real build job.
# Read-only. Any structurally-correct workflow passes.
. "$AZTRAIN_REPO/lib/common.sh"

CI="$AZTRAIN_WS/ci.yml"

check_eval "ci.yml exists in your workspace" '[ -f "$CI" ]'
if [ ! -f "$CI" ]; then grade_summary; exit $?; fi
check_eval "ci.yml parses as supported YAML" \
  'python3 -c "import sys;sys.path.insert(0,\"$AZTRAIN_REPO/tools\");import yamlmini as y;y.load_file(\"$CI\")"'

python3 - "$CI" "$AZTRAIN_REPO/tools" <<'EOF'
import sys
sys.path.insert(0, sys.argv[2])
import yamlmini as y

try:
    d = y.load_file(sys.argv[1])
except Exception as e:
    print(f"  ✗ ci.yml did not parse: {e}")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

on = y.dig(d, "on")
check("top-level 'on:' trigger is a mapping", isinstance(on, dict))
on = on if isinstance(on, dict) else {}

def as_list(v):
    if v is None: return []
    return v if isinstance(v, list) else [v]

def targets_main(branches):
    return any(str(b).strip() == "main" for b in as_list(branches))

def scopes_paths(paths):
    return len(as_list(paths)) >= 1

for trig in ("push", "pull_request"):
    t = on.get(trig)
    check(f"'{trig}' trigger present as a mapping", isinstance(t, dict))
    t = t if isinstance(t, dict) else {}
    check(f"'{trig}' limited to the main branch", targets_main(t.get("branches")))
    check(f"'{trig}' has a paths filter scoping the build", scopes_paths(t.get("paths")))

jobs = y.dig(d, "jobs")
check("'jobs:' is a non-empty mapping", isinstance(jobs, dict) and len(jobs) > 0)
jobs = jobs if isinstance(jobs, dict) else {}
good_job = False
for name, job in jobs.items():
    if not isinstance(job, dict):
        continue
    steps = job.get("steps")
    if job.get("runs-on") and isinstance(steps, list) and len(steps) >= 1 \
       and all(isinstance(s, dict) for s in steps):
        good_job = True
        break
check("has a job with 'runs-on' and a non-empty steps list of mappings", good_job)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow is scoped to the trunk and the API path" '[ "$PY_RC" -eq 0 ]'
grade_summary
