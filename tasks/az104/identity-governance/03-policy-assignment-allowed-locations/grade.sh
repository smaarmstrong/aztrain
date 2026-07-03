#!/usr/bin/env bash
# Compile the learner's Bicep and assert facts about the policyAssignment. Read-only.
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
assigns = [r for r in t.get("resources", [])
           if r.get("type") == "Microsoft.Authorization/policyAssignments"]

def resolve(expr):
    """Inline one level of variables() and parameter defaults so the
    definition id can be given via a var/param."""
    s = json.dumps(expr) if not isinstance(expr, str) else expr
    def subvar(m):
        v = variables.get(m.group(1), "")
        return v.strip("[]'") if isinstance(v, str) else ""
    return re.sub(r"variables\('([^']+)'\)", subvar, s)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

BUILTIN = "e56962a6-4747-49cd-b67b-bf8b01975c4c"

al = params.get("allowedlocations", {})
dflt = al.get("defaultValue")
check("parameter 'allowedLocations' is an array", al.get("type", "").lower() == "array")
check("allowedLocations defaults to ['uksouth', 'ukwest']",
      isinstance(dflt, list) and [str(x).lower() for x in dflt] == ["uksouth", "ukwest"])

check("exactly one policyAssignments resource", len(assigns) == 1)
a = assigns[0] if assigns else {}
props = a.get("properties", {})

defid = resolve(props.get("policyDefinitionId", ""))
check("policyDefinitionId is the built-in 'Allowed locations' id",
      BUILTIN in defid)

dn = props.get("displayName", "")
check("assignment has a non-empty displayName", isinstance(dn, str) and dn.strip() != "")

pol_params = props.get("parameters", {})
lol = pol_params.get("listOfAllowedLocations", {})
val = json.dumps(lol.get("value", ""))
check("passes listOfAllowedLocations parameter", "listOfAllowedLocations" in pol_params)
check("listOfAllowedLocations.value is wired to the allowedLocations parameter",
      "parameters('allowedLocations')" in val or "parameters('allowedlocations')" in val.lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the assignment spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
