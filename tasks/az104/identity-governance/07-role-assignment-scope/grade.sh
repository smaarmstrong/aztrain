#!/usr/bin/env bash
# Compile the learner's Bicep and assert the Reader role assignment. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

BICEP="$AZTRAIN_WS/main.bicep"
COMPILED=$(mktemp)
trap 'rm -f "$COMPILED"' EXIT

check_eval "main.bicep exists in your workspace" '[ -f "$BICEP" ]'
if ! bicep_build "$BICEP" > "$COMPILED" 2>/dev/null || [ ! -s "$COMPILED" ]; then
  check_eval "main.bicep compiles (az bicep build)" 'false'
  grade_summary; exit $?
fi
check_eval "main.bicep compiles (az bicep build)" 'true'

python3 - "$COMPILED" <<'EOF'
import json, re, sys

t = json.load(open(sys.argv[1]))
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
variables = t.get("variables", {})
ras = [r for r in t.get("resources", [])
       if r.get("type") == "Microsoft.Authorization/roleAssignments"]

def resolve(expr):
    """Inline one level of variables() so a def-id stashed in a var is seen."""
    s = expr if isinstance(expr, str) else json.dumps(expr)
    def subvar(m):
        v = variables.get(m.group(1), "")
        return json.dumps(v) if not isinstance(v, str) else v
    return re.sub(r"variables\('([^']+)'\)", subvar, s)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

READER = "acdd72a7-3385-48ef-bd42-f606fba81ae7"

check("parameter 'principalId' (string)",
      params.get("principalid", {}).get("type", "").lower() == "string")
check("exactly one roleAssignments resource", len(ras) == 1)
a = ras[0] if ras else {}
props = a.get("properties", {})

check("roleDefinitionId resolves to the built-in Reader role",
      READER in resolve(props.get("roleDefinitionId", "")))
check("principalId comes from the principalId parameter",
      "parameters('principalId')" in str(props.get("principalId", "")))
check("principalType is 'Group'", props.get("principalType") == "Group")
check("assignment name is produced by guid(...)",
      "guid(" in resolve(a.get("name", "")))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the role-assignment spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
