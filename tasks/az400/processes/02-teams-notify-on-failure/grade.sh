#!/usr/bin/env bash
# Assert the CI workflow notifies Microsoft Teams when the build fails, gated
# by a failure() condition, using a webhook pulled from a secret (never inline).
# Structure only. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/ci.yml"
check_eval "ci.yml exists in your workspace" '[ -f "$WF" ]'
if [ ! -f "$WF" ]; then grade_summary; exit $?; fi

check_eval "ci.yml parses as YAML" \
  'python3 -c "import sys; sys.path.insert(0,\"$AZTRAIN_REPO/tools\"); import yamlmini as y; y.load_file(\"$WF\")"'

# No raw Teams webhook URL committed anywhere in the file.
check_eval "no hardcoded Teams webhook URL in the YAML" \
  '! grep -Eiq "https://[a-z0-9.-]*(webhook\.office\.com|office\.com/webhook|logic\.azure\.com)" "$WF"'

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

jobs = y.dig(d, "jobs")
check("defines at least one job", isinstance(jobs, dict) and len(jobs) >= 1)

def steps_of(job):
    s = y.dig(job, "steps")
    return s if isinstance(s, list) else []

def step_blob(st):
    parts = []
    for k in ("uses", "run", "name"):
        v = y.dig(st, k)
        if isinstance(v, str):
            parts.append(v)
    # include the 'with' values too (webhook can be a step input)
    w = y.dig(st, "with")
    if isinstance(w, dict):
        parts += [str(v) for v in w.values()]
    return "\n".join(parts)

def is_teams(blob):
    b = blob.lower()
    return ("teams" in b) or ("office.com" in b) or ("msteams" in b)

# Find a notify step that targets Teams, and figure out where its 'if' gate is
# (either on the step or on its enclosing job).
notify_found = False
notify_gated = False
notify_uses_secret = False

def gated(cond):
    if not isinstance(cond, str):
        return False
    c = cond.lower().replace(" ", "")
    return "failure()" in c or ("==" in c and "failure" in c)

for job in (jobs.values() if isinstance(jobs, dict) else []):
    job_if = y.dig(job, "if")
    for st in steps_of(job):
        blob = step_blob(st)
        if is_teams(blob):
            notify_found = True
            step_if = y.dig(st, "if")
            if gated(step_if) or gated(job_if):
                notify_gated = True
            if "${{ secrets." in blob or "secrets." in blob:
                notify_uses_secret = True

check("a step posts a notification to Microsoft Teams", notify_found)
check("the notification only fires on failure (if: failure())", notify_gated)
check("the webhook comes from a secret, not an inline literal", notify_uses_secret)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the Teams-notify spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
