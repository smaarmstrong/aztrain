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
res = t.get("resources", [])
vnets = [r for r in res if r.get("type") == "Microsoft.Network/virtualNetworks"]
# peering may be a top-level resource or nested under the VNet's "resources"
peers = [r for r in res
         if r.get("type") == "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"]
for v in vnets:
    for c in v.get("resources", []) or []:
        if c.get("type", "").endswith("virtualNetworkPeerings"):
            peers.append(c)

def names(r):
    return str(r.get("name", ""))

def vnet_by_space(space):
    for v in vnets:
        pfx = v.get("properties", {}).get("addressSpace", {}).get("addressPrefixes", [])
        if space in pfx:
            return v
    return None

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))

check("two virtual networks", len(vnets) == 2)
hub = vnet_by_space("10.0.0.0/16")
spoke = vnet_by_space("10.1.0.0/16")
check("a VNet 'vnet-hub' with address space 10.0.0.0/16",
      hub is not None and "vnet-hub" in names(hub))
check("a VNet 'vnet-spoke' with address space 10.1.0.0/16",
      spoke is not None and "vnet-spoke" in names(spoke))

check("exactly one virtualNetworkPeerings resource", len(peers) == 1)
peer = peers[0] if peers else {}
pname = names(peer)
check("peering named 'spoke-to-hub'", "spoke-to-hub" in pname)
check("peering is a child of vnet-spoke",
      "vnet-spoke" in pname)
pp = peer.get("properties", {})
remote = str(pp.get("remoteVirtualNetwork", {}).get("id", ""))
check("remoteVirtualNetwork points at vnet-hub", "vnet-hub" in remote)
check("allowForwardedTraffic is true", pp.get("allowForwardedTraffic") is True)
check("allowVirtualNetworkAccess is true", pp.get("allowVirtualNetworkAccess") is True)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
