#!/usr/bin/env bash
# Compile the learner's Bicep and assert the MG hierarchy + tenant scope. Read-only.
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
import json, sys

t = json.load(open(sys.argv[1]))
schema = t.get("$schema", "")
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
mgs = [r for r in t.get("resources", [])
       if r.get("type") == "Microsoft.Management/managementGroups"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("targetScope is 'tenant'", "tenantDeploymentTemplate" in schema)
check("parameter 'platformMgName' (string)",
      params.get("platformmgname", {}).get("type", "").lower() == "string")
check("parameter 'landingZonesMgName' (string)",
      params.get("landingzonesmgname", {}).get("type", "").lower() == "string")
check("exactly two management groups declared", len(mgs) == 2)

def name_expr(r):
    return str(r.get("name", ""))

# The parent is the MG named from platformMgName; the child references it.
platform = next((m for m in mgs if "platformMgName" in name_expr(m)), None)
child    = next((m for m in mgs if "landingZonesMgName" in name_expr(m)), None)
check("Platform MG named from platformMgName parameter", platform is not None)
check("Landing Zones MG named from landingZonesMgName parameter", child is not None)

if platform:
    dn = platform.get("properties", {}).get("displayName", "")
    check("Platform MG has a non-empty displayName", isinstance(dn, str) and dn.strip() != "")
else:
    check("Platform MG has a non-empty displayName", False)

if child:
    parent_id = json.dumps(child.get("properties", {}).get("details", {})
                           .get("parent", {}).get("id", ""))
    # Accept mg.id (-> tenantResourceId), managementGroupResourceId, or a
    # literal .../managementGroups/<platform name> reference.
    refs_platform = ("platformMgName" in parent_id) and (
        "managementGroups" in parent_id or "ResourceId" in parent_id)
    check("Landing Zones MG's details.parent.id points at the Platform MG", refs_platform)
else:
    check("Landing Zones MG's details.parent.id points at the Platform MG", False)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the hierarchy spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
