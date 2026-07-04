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
def of_type(name):
    return [r for r in res if r.get("type", "").lower() == name.lower()]

storage = of_type("Microsoft.Storage/storageAccounts")
plans = of_type("Microsoft.Web/serverfarms")
sites = of_type("Microsoft.Web/sites")

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(params.get("location", {}).get("defaultValue", "")))
check("a StorageV2 Standard_LRS storage account exists",
      any(s.get("kind") == "StorageV2" and s.get("sku", {}).get("name") == "Standard_LRS"
          for s in storage))

consumption = [p for p in plans
               if p.get("sku", {}).get("name") == "Y1"
               and str(p.get("sku", {}).get("tier", "")).lower() == "dynamic"]
check("a Consumption plan (SKU Y1, tier Dynamic) exists", len(consumption) >= 1)

check("exactly one Function App (sites)", len(sites) == 1)
site = sites[0] if sites else {}
sprops = site.get("properties", {})
check("app kind marks it a function app",
      "functionapp" in str(site.get("kind", "")).lower())
check("Function App bound to the plan (serverFarmId)",
      "serverfarms" in str(sprops.get("serverFarmId", "")).lower())
check("httpsOnly is true", sprops.get("httpsOnly") is True)
settings = {str(s.get("name")) for s in sprops.get("siteConfig", {}).get("appSettings", [])}
check("appSettings includes AzureWebJobsStorage", "AzureWebJobsStorage" in settings)
check("appSettings includes FUNCTIONS_WORKER_RUNTIME", "FUNCTIONS_WORKER_RUNTIME" in settings)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
