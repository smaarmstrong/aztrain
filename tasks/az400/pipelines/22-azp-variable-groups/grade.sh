#!/usr/bin/env bash
# Structurally grade variable-group + pipeline-variable usage. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

PIPE="$AZTRAIN_WS/azure-pipelines.yml"
check_eval "azure-pipelines.yml exists in your workspace" '[ -f "$PIPE" ]'
check_eval "azure-pipelines.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$PIPE" >/dev/null'

python3 - "$AZTRAIN_REPO" "$PIPE" <<'EOF'
import re
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

variables = y.dig(d, "variables")
check("variables: is the list form", isinstance(variables, list))
vlist = variables if isinstance(variables, list) else []

groups = [str(v.get("group")) for v in vlist if isinstance(v, dict) and v.get("group")]
check("references a variable group via '- group:'", len(groups) >= 1)

named = [str(v.get("name")) for v in vlist
         if isinstance(v, dict) and v.get("name") is not None and "value" in v]
check("declares at least one named pipeline variable (name/value)", len(named) >= 1)

# a step consumes a variable via the $(...) macro syntax
text = open(sys.argv[2]).read()
check("a step references a variable with the $(...) macro syntax",
      re.search(r"\$\([A-Za-z_][A-Za-z0-9_.]*\)", text) is not None)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "variable wiring satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
