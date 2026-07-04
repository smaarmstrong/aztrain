#!/usr/bin/env bash
# Structurally grade GitHub Actions trigger rules. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/release.yml"
check_eval "release.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "release.yml parses as YAML (yamlmini)" \
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

on = y.dig(d, "on")
on = on if isinstance(on, dict) else {}

def as_list(v):
    return v if isinstance(v, list) else ([v] if v is not None else [])

tags = as_list(y.dig(on, "push", "tags"))
check("triggers on version tags (push → tags: v*)",
      any("v" in str(t) for t in tags))

sched = as_list(y.dig(on, "schedule"))
check("has a nightly schedule (schedule → cron)",
      any(isinstance(s, dict) and str(s.get("cron", "")).strip() for s in sched))

branches = as_list(y.dig(on, "push", "branches"))
paths = as_list(y.dig(on, "push", "paths"))
check("push to main is path-filtered to src/**",
      "main" in [str(b) for b in branches] and any("src" in str(p) for p in paths))

check("allows manual runs (workflow_dispatch)", "workflow_dispatch" in on)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow triggers are correctly scoped" '[ "$PY_RC" -eq 0 ]'
grade_summary
