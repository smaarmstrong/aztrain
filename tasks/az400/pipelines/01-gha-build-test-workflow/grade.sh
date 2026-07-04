#!/usr/bin/env bash
# Structurally grade a GitHub Actions CI workflow. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/ci.yml"
check_eval "ci.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "ci.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$WF" >/dev/null'

python3 - "$AZTRAIN_REPO" "$WF" <<'EOF'
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

on = y.dig(d, "on") or {}
def branch_scoped(trig):
    node = y.dig(on, trig)
    if node is None or node is True:
        return False
    branches = y.dig(node, "branches")
    return isinstance(branches, list) and "main" in branches

check("triggers on push to the main branch", branch_scoped("push"))
check("triggers on pull_request to the main branch", branch_scoped("pull_request"))

job = y.dig(d, "jobs", "build") or {}
check("job 'build' runs on an ubuntu hosted runner",
      str(y.dig(job, "runs-on") or "").startswith("ubuntu"))

steps = y.dig(job, "steps")
steps = steps if isinstance(steps, list) else []
uses = [str(s.get("uses", "")) for s in steps if isinstance(s, dict)]
runs = [str(s.get("run", "")) for s in steps if isinstance(s, dict) and s.get("run")]

check("a step checks the code out (actions/checkout)",
      any("actions/checkout" in u for u in uses))
check("a step sets up a language runtime (setup-* action)",
      any("setup-" in u for u in uses))
check("a run step builds the app", len(runs) >= 1)
check("a distinct run step executes tests", len(runs) >= 2)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the CI spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
