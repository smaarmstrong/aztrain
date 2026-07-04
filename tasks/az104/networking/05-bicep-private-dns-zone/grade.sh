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
res = t.get("resources", [])

def by_type(tp):
    return [r for r in res if r.get("type") == tp]

# child resources may also be nested; flatten one level
def all_of_type(tp):
    out = list(by_type(tp))
    for r in res:
        for c in r.get("resources", []) or []:
            if c.get("type", "").split("/")[-2:] == tp.split("/")[-2:]:
                out.append(c)
    return out

zones = by_type("Microsoft.Network/privateDnsZones")
arecs = all_of_type("Microsoft.Network/privateDnsZones/A")
links = all_of_type("Microsoft.Network/privateDnsZones/virtualNetworkLinks")

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("one private DNS zone named 'corp.internal'",
      len(zones) == 1 and "corp.internal" in str(zones[0].get("name", "")))

check("exactly one A record", len(arecs) == 1)
a = arecs[0] if arecs else {}
aname = str(a.get("name", ""))
check("A record named 'app' in the zone",
      "app" in aname and "corp.internal" in aname)
ap = a.get("properties", {})
check("A record TTL is 3600", ap.get("ttl") == 3600)
ips = [rec.get("ipv4Address") for rec in ap.get("aRecords", []) or []]
check("A record resolves to 10.30.1.10", "10.30.1.10" in ips)

check("exactly one virtual network link", len(links) == 1)
lk = links[0] if links else {}
lname = str(lk.get("name", ""))
check("link named 'link-vnet-app' in the zone",
      "link-vnet-app" in lname and "corp.internal" in lname)
target = str(lk.get("properties", {}).get("virtualNetwork", {}).get("id", ""))
check("link's virtualNetwork points at vnet-app", "vnet-app" in target)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
