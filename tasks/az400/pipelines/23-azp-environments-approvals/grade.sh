#!/usr/bin/env bash
# Structurally grade a deployment job targeting a YAML environment. Read-only.
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

# collect all jobs across all stages (or a top-level jobs: list)
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

def env_name(job):
    env = job.get("environment")
    if isinstance(env, str):
        return env
    if isinstance(env, dict):
        return str(env.get("name", ""))
    return ""

prod = [j for j in deployments if env_name(j) == "production"]
check("the deployment job targets environment 'production'", len(prod) >= 1)

def has_runonce_steps(job):
    steps = y.dig(job, "strategy", "runOnce", "deploy", "steps")
    return isinstance(steps, list) and len(steps) >= 1

check("uses a runOnce strategy with deploy.steps",
      any(has_runonce_steps(j) for j in prod))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "environment deployment satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
