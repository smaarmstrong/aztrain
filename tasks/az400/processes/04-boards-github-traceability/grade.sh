#!/usr/bin/env bash
# Assert Azure Boards <-> GitHub traceability: a PR template that prompts for an
# AB#<id> link, and a workflow that enforces the link on pull requests.
# Structure only. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/require-workitem.yml"
TMPL="$AZTRAIN_WS/pull_request_template.md"

check_eval "require-workitem.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "pull_request_template.md exists in your workspace" '[ -f "$TMPL" ]'
if [ ! -f "$WF" ] || [ ! -f "$TMPL" ]; then grade_summary; exit $?; fi

check_eval "require-workitem.yml parses as YAML" \
  'python3 -c "import sys; sys.path.insert(0,\"$AZTRAIN_REPO/tools\"); import yamlmini as y; y.load_file(\"$WF\")"'

# The PR template must prompt for an Azure Boards work-item link (AB#).
check_eval "PR template prompts for an AB# work-item link" \
  'grep -Eq "AB#" "$TMPL"'

python3 - "$WF" <<'EOF'
import sys, os
sys.path.insert(0, os.environ["AZTRAIN_REPO"] + "/tools")
import yamlmini as y

d = y.load_file(sys.argv[1])
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

trig = y.dig(d, "on") or y.dig(d, True)
check("workflow triggers on pull_request",
      isinstance(trig, dict) and "pull_request" in trig)

jobs = y.dig(d, "jobs")
check("defines at least one job", isinstance(jobs, dict) and len(jobs) >= 1)

# Somewhere a step checks the PR for an AB#<id> reference and fails if absent.
def steps_of(job):
    s = y.dig(job, "steps")
    return s if isinstance(s, list) else []

enforce = False
for job in (jobs.values() if isinstance(jobs, dict) else []):
    for st in steps_of(job):
        blob = "\n".join(str(y.dig(st, k) or "") for k in ("run", "uses", "with"))
        env = y.dig(st, "env")
        if isinstance(env, dict):
            blob += "\n" + "\n".join(str(v) for v in env.values())
        if "AB#" in blob and ("exit 1" in blob or "::error" in blob or "workitem" in blob.lower() or "work-item" in blob.lower()):
            enforce = True

check("a step enforces an AB# work-item reference on the PR", enforce)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "traceability config satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
