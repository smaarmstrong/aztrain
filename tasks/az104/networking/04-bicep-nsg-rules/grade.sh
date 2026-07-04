#!/usr/bin/env bash
# Compile the learner's Bicep, extract the NSG rules, then assert BEHAVIOUR via
# tools/nsgsim.py (same evaluator Azure uses). Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

BICEP="$AZTRAIN_WS/main.bicep"
COMPILED=$(mktemp)
RULES=$(mktemp)
trap 'rm -f "$COMPILED" "$RULES"' EXIT

check_eval "main.bicep exists in your workspace" '[ -f "$BICEP" ]'
if ! bicep_build "$BICEP" > "$COMPILED" 2>/dev/null || [ ! -s "$COMPILED" ]; then
  check_eval "main.bicep compiles (az bicep build)" 'false'
  grade_summary; exit $?
fi
check_eval "main.bicep compiles (az bicep build)" 'true'

# Pull the compiled securityRules into the flat [{...properties...}] shape that
# nsgsim.py expects (a list of rule-property objects with a "name").
python3 - "$COMPILED" "$RULES" <<'EOF'
import json, sys

t = json.load(open(sys.argv[1]))
res = t.get("resources", [])
nsgs = [r for r in res if r.get("type") == "Microsoft.Network/networkSecurityGroups"]

structural_ok = True
reasons = []
if len(nsgs) != 1:
    structural_ok = False
    reasons.append(f"expected exactly one NSG, found {len(nsgs)}")

nsg = nsgs[0] if nsgs else {}
name = str(nsg.get("name", ""))
if "nsg-web" not in name:
    structural_ok = False
    reasons.append("NSG is not named 'nsg-web'")

# rules may be inline (securityRules) or child securityRules resources
rules = []
for r in nsg.get("properties", {}).get("securityRules", []) or []:
    props = r.get("properties", r)
    props = dict(props)
    props.setdefault("name", r.get("name"))
    rules.append(props)
for c in res:
    if c.get("type") == "Microsoft.Network/networkSecurityGroups/securityRules":
        props = dict(c.get("properties", {}))
        props.setdefault("name", str(c.get("name")).split("/")[-1])
        rules.append(props)

if not any(str(r.get("access")) == "Allow" for r in rules):
    structural_ok = False
    reasons.append("no explicit Allow rule authored")
if not any(str(r.get("access")) == "Deny" for r in rules):
    structural_ok = False
    reasons.append("no explicit Deny rule authored")

json.dump(rules, open(sys.argv[2], "w"))
sys.exit(0 if structural_ok else 1)
EOF
STRUCT_RC=$?
check_eval "one NSG 'nsg-web' with explicit Allow and Deny rules" '[ "$STRUCT_RC" -eq 0 ]'

SIM="python3 $AZTRAIN_REPO/tools/nsgsim.py $RULES --direction Inbound --source Internet --protocol Tcp"
check_eval "inbound TCP 443 from the Internet is ALLOWED" "$SIM --port 443"
check_eval "inbound TCP 80 from the Internet is DENIED"   "! $SIM --port 80"
check_eval "inbound TCP 22 from the Internet is DENIED"   "! $SIM --port 22"

grade_summary
