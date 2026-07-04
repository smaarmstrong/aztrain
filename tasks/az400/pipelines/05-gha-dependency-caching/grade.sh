#!/usr/bin/env bash
# Structurally grade dependency caching in a GitHub Actions workflow. Read-only.
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

steps = y.dig(d, "jobs", "build", "steps") or []
cache = next((s for s in steps
              if isinstance(s, dict) and "actions/cache" in str(s.get("uses", ""))), None)
check("a step uses actions/cache", cache is not None)
w = (cache or {}).get("with", {}) if isinstance((cache or {}).get("with", {}), dict) else {}
check("the cache step sets a path", bool(str(w.get("path", "")).strip()))
check("the cache key invalidates on the lockfile (hashFiles)",
      "hashfiles(" in str(w.get("key", "")).lower())
check("the code is still checked out",
      any("actions/checkout" in str(s.get("uses", "")) for s in steps if isinstance(s, dict)))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow caches dependencies keyed on the lockfile" '[ "$PY_RC" -eq 0 ]'
grade_summary
