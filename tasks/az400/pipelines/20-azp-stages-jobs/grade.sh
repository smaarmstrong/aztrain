#!/usr/bin/env bash
# Structurally grade a multi-stage Azure Pipeline. Read-only.
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

# trigger: either shorthand list [main] or trigger.branches.include: [main]
trig = y.dig(d, "trigger")
def triggers_main(t):
    if isinstance(t, list):
        return "main" in [str(x) for x in t]
    inc = y.dig(t, "branches", "include")
    return isinstance(inc, list) and "main" in [str(x) for x in inc]
check("triggers on the main branch", triggers_main(trig))

check("pool uses a Microsoft-hosted vmImage",
      bool(str(y.dig(d, "pool", "vmImage") or "")))

stages = y.dig(d, "stages")
stages = stages if isinstance(stages, list) else []
check("has a top-level stages: list with >= 2 stages", len(stages) >= 2)

by_name = {str(s.get("stage")): s for s in stages if isinstance(s, dict) and s.get("stage")}
build = by_name.get("Build")
deploy = by_name.get("Deploy")
check("a stage named 'Build' exists", build is not None)
check("a stage named 'Deploy' exists", deploy is not None)

def stage_has_job_with_steps(stage):
    jobs = y.dig(stage or {}, "jobs")
    jobs = jobs if isinstance(jobs, list) else []
    for j in jobs:
        steps = y.dig(j, "steps") if isinstance(j, dict) else None
        if isinstance(steps, list) and len(steps) >= 1:
            return True
    return False

check("Build stage has a job with a steps: list", stage_has_job_with_steps(build))
check("Deploy stage has a job with a steps: list", stage_has_job_with_steps(deploy))

# Deploy depends on Build (dependsOn is a string or a list)
dep = y.dig(deploy or {}, "dependsOn")
deps = dep if isinstance(dep, list) else [dep]
check("Deploy stage dependsOn Build", "Build" in [str(x) for x in deps])

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "pipeline satisfies the multi-stage spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
