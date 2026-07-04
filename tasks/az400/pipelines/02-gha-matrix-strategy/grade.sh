#!/usr/bin/env bash
# Structurally grade a GitHub Actions matrix build. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/ci.yml"
check_eval "ci.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "ci.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$WF" >/dev/null'

python3 - "$AZTRAIN_REPO" "$WF" <<'EOF'
import json, sys
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

job = y.dig(d, "jobs", "build") or {}
matrix = y.dig(job, "strategy", "matrix")
matrix = matrix if isinstance(matrix, dict) else {}

check("build job declares strategy.matrix", bool(matrix))

os_axis = matrix.get("os")
check("matrix has an 'os' axis with >= 2 operating systems",
      isinstance(os_axis, list) and len(os_axis) >= 2)

# A version axis: any list-valued axis other than 'os' with >= 3 values.
version_axes = [k for k, v in matrix.items()
                if k != "os" and isinstance(v, list) and len(v) >= 3]
check("matrix has a version axis with >= 3 values", bool(version_axes))

runs_on = str(y.dig(job, "runs-on") or "")
check("runs-on is driven by the matrix os axis (matrix.os)",
      "matrix.os" in runs_on)

# The version value is consumed somewhere (setup with-block or a run command).
blob = json.dumps([s for s in (y.dig(job, "steps") or [])])
check("a step consumes the matrix version value",
      any(f"matrix.{k}" in blob for k in version_axes))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the matrix spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
