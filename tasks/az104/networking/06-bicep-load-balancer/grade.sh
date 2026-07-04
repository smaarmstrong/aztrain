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

import re
t = json.load(open(sys.argv[1]))
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
variables = t.get("variables", {})
res = t.get("resources", [])

def resolve(expr):
    """Inline one level of variables() so a name plumbed through a var passes."""
    if not isinstance(expr, str):
        return str(expr)
    def sub(m):
        v = variables.get(m.group(1), "")
        return v.strip("[]") if isinstance(v, str) else ""
    return re.sub(r"variables\('([^']+)'\)", sub, expr)
pips = [r for r in res if r.get("type") == "Microsoft.Network/publicIPAddresses"]
lbs = [r for r in res if r.get("type") == "Microsoft.Network/loadBalancers"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def named(items, want):
    for it in items:
        if it.get("name") == want:
            return it
    return None

loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))

pip = next((p for p in pips if "pip-lb" in str(p.get("name", ""))), None)
check("public IP 'pip-lb' exists", pip is not None)
pip = pip or {}
check("public IP is Standard SKU",
      pip.get("sku", {}).get("name") == "Standard")
check("public IP allocation is Static",
      pip.get("properties", {}).get("publicIPAllocationMethod") == "Static")

check("exactly one load balancer", len(lbs) == 1)
lb = lbs[0] if lbs else {}
check("load balancer named 'lb-web'", "lb-web" in resolve(lb.get("name", "")))
check("load balancer is Standard SKU",
      lb.get("sku", {}).get("name") == "Standard")

lp = lb.get("properties", {})
fe = named(lp.get("frontendIPConfigurations", []) or [], "frontend")
check("frontend IP config 'frontend' bound to pip-lb",
      fe is not None and "pip-lb" in str(fe.get("properties", {}).get("publicIPAddress", {}).get("id", "")))

pool = named(lp.get("backendAddressPools", []) or [], "pool-web")
check("backend address pool 'pool-web' exists", pool is not None)

probe = named(lp.get("probes", []) or [], "probe-http")
check("health probe 'probe-http' exists", probe is not None)
pr = (probe or {}).get("properties", {})
check("probe is Tcp on port 80",
      pr.get("protocol") == "Tcp" and pr.get("port") == 80)

rule = named(lp.get("loadBalancingRules", []) or [], "rule-http")
check("load balancing rule 'rule-http' exists", rule is not None)
rp = (rule or {}).get("properties", {})
check("rule is Tcp, frontend port 80 -> backend port 80",
      rp.get("protocol") == "Tcp" and rp.get("frontendPort") == 80 and rp.get("backendPort") == 80)
check("rule references the 'frontend' frontend IP config",
      "frontend" in str(rp.get("frontendIPConfiguration", {}).get("id", "")))
check("rule references the 'pool-web' backend pool",
      "pool-web" in str(rp.get("backendAddressPool", {}).get("id", "")))
check("rule references the 'probe-http' probe",
      "probe-http" in str(rp.get("probe", {}).get("id", "")))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
