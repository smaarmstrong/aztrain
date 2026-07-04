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
plans = [r for r in res if r.get("type") == "Microsoft.Web/serverfarms"]
sites = [r for r in res if r.get("type") == "Microsoft.Web/sites"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("parameter 'appName' (string)", params.get("appname", {}).get("type", "").lower() == "string")
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(params.get("location", {}).get("defaultValue", "")))
check("exactly one App Service plan (serverfarms)", len(plans) == 1)
check("exactly one web app (sites)", len(sites) == 1)

plan = plans[0] if plans else {}
check("plan SKU name is B1", plan.get("sku", {}).get("name") == "B1")
check("plan is a Linux plan (reserved true)",
      plan.get("properties", {}).get("reserved") is True
      or str(plan.get("kind", "")).lower() == "linux")

site = sites[0] if sites else {}
sprops = site.get("properties", {})
check("web app is bound to the plan (serverFarmId)",
      "serverfarms" in str(sprops.get("serverFarmId", "")).lower())
check("httpsOnly is true", sprops.get("httpsOnly") is True)
lfx = str(sprops.get("siteConfig", {}).get("linuxFxVersion", ""))
check("siteConfig sets a linuxFxVersion runtime", len(lfx.strip()) > 0)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
