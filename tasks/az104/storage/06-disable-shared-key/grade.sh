#!/usr/bin/env bash
# Compile the learner's Bicep and assert shared-key access is disabled. Read-only.
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
sas = [r for r in t.get("resources", []) if r.get("type") == "Microsoft.Storage/storageAccounts"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

p = params.get("storageaccountname", {})
check("parameter 'storageAccountName' (string)", p.get("type", "").lower() == "string")
loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))
check("exactly one storage account resource", len(sas) == 1)
sa = sas[0] if sas else {}
props = sa.get("properties", {})
check("kind StorageV2", sa.get("kind") == "StorageV2")
check("SKU Standard_LRS", sa.get("sku", {}).get("name") == "Standard_LRS")
check("allowSharedKeyAccess is false (no account-key/SAS auth)",
      props.get("allowSharedKeyAccess") is False)
check("defaultToOAuthAuthentication is true (Entra is the default)",
      props.get("defaultToOAuthAuthentication") is True)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
