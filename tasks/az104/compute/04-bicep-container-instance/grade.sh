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
import json, re, sys

t = json.load(open(sys.argv[1]))
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
res = t.get("resources", [])
groups = [r for r in res if r.get("type") == "Microsoft.ContainerInstance/containerGroups"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def as_num(v):
    """Accept a literal number or an ARM json('1.0') expression."""
    if isinstance(v, (int, float)):
        return float(v)
    m = re.search(r"json\('?([-0-9.]+)'?\)", str(v))
    if m:
        return float(m.group(1))
    try:
        return float(v)
    except (TypeError, ValueError):
        return None

check("parameter 'containerGroupName' (string)",
      params.get("containergroupname", {}).get("type", "").lower() == "string")
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(params.get("location", {}).get("defaultValue", "")))
check("exactly one container group", len(groups) == 1)

g = groups[0] if groups else {}
props = g.get("properties", {})
check("osType is Linux", str(props.get("osType", "")).lower() == "linux")
containers = props.get("containers", [])
check("at least one container defined", len(containers) >= 1)

c = containers[0].get("properties", {}) if containers else {}
reqs = c.get("resources", {}).get("requests", {})
check("container requests 1 CPU", as_num(reqs.get("cpu")) == 1.0)
check("container requests 1 GB memory", as_num(reqs.get("memoryInGB")) == 1.0)
cports = {p.get("port") for p in c.get("ports", [])}
check("container exposes port 80", 80 in cports)

ip = props.get("ipAddress", {})
check("group has a public IP address", str(ip.get("type", "")).lower() == "public")
gports = {p.get("port") for p in ip.get("ports", [])}
check("public IP opens port 80", 80 in gports)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
