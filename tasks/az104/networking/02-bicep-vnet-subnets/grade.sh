#!/usr/bin/env bash
# Compile the learner's Bicep and assert facts about the ARM JSON. Read-only.
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
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
outputs = {k.lower(): v for k, v in t.get("outputs", {}).items()}
res = t.get("resources", [])
vnets = [r for r in res if r.get("type") == "Microsoft.Network/virtualNetworks"]
child_subnets = [r for r in res
                 if r.get("type") == "Microsoft.Network/virtualNetworks/subnets"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))

check("exactly one virtual network resource", len(vnets) == 1)
vnet = vnets[0] if vnets else {}
check("virtual network named 'vnet-app'", str(vnet.get("name", "")).strip("[]") == "vnet-app"
      or "'vnet-app'" in str(vnet.get("name", "")))

vprops = vnet.get("properties", {})
prefixes = vprops.get("addressSpace", {}).get("addressPrefixes", [])
check("address space is 10.20.0.0/16", "10.20.0.0/16" in prefixes)

# Subnets may be inline on the VNet or declared as child resources.
subnets = {}
for s in vprops.get("subnets", []) or []:
    subnets[s.get("name")] = s.get("properties", {}).get("addressPrefix")
for c in child_subnets:
    name = str(c.get("name", ""))
    # child name is "vnet-app/snet-web" (possibly wrapped in an ARM expr)
    leaf = name.rstrip("]").split("/")[-1].strip("'")
    subnets[leaf] = c.get("properties", {}).get("addressPrefix")

check("exactly two subnets", len(subnets) == 2)
check("subnet 'snet-web' has prefix 10.20.1.0/24",
      subnets.get("snet-web") == "10.20.1.0/24")
check("subnet 'snet-data' has prefix 10.20.2.0/24",
      subnets.get("snet-data") == "10.20.2.0/24")

out = outputs.get("subnetids", {})
check("output 'subnetIds' is an array",
      out.get("type", "").lower() == "array")

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
