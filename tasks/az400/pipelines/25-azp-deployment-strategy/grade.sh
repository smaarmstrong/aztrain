#!/usr/bin/env bash
# Structurally grade a canary deployment strategy. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

PIPE="$AZTRAIN_WS/azure-pipelines.yml"
check_eval "azure-pipelines.yml exists in your workspace" '[ -f "$PIPE" ]'
check_eval "azure-pipelines.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$PIPE" >/dev/null'

python3 - "$AZTRAIN_REPO" "$PIPE" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

try:
    d = y.load_file(sys.argv[2])
except Exception as e:
    print(f"  ✗ parse error: {e}")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def all_jobs(doc):
    jobs = []
    stages = y.dig(doc, "stages")
    if isinstance(stages, list):
        for s in stages:
            js = y.dig(s, "jobs") if isinstance(s, dict) else None
            if isinstance(js, list):
                jobs.extend(js)
    top = y.dig(doc, "jobs")
    if isinstance(top, list):
        jobs.extend(top)
    return [j for j in jobs if isinstance(j, dict)]

jobs = all_jobs(d)
deployments = [j for j in jobs if j.get("deployment")]
check("a deployment job (deployment:) exists", len(deployments) >= 1)

canaries = [j for j in deployments if isinstance(y.dig(j, "strategy", "canary"), dict)]
check("the deployment job uses a canary strategy", len(canaries) >= 1)

def canary_ok(job):
    increments = y.dig(job, "strategy", "canary", "increments")
    steps = y.dig(job, "strategy", "canary", "deploy", "steps")
    return isinstance(increments, list) and len(increments) >= 1 \
        and isinstance(steps, list) and len(steps) >= 1

check("canary declares an increments: list", any(
    isinstance(y.dig(j, "strategy", "canary", "increments"), list)
    and len(y.dig(j, "strategy", "canary", "increments")) >= 1
    for j in canaries))
check("canary has deploy.steps", any(canary_ok(j) for j in canaries))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "canary deployment satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
