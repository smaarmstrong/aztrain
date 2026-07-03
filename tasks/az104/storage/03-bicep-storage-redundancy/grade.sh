#!/usr/bin/env bash
# Compile the learner's Bicep and assert the redundancy SKU. Read-only.
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
variables = t.get("variables", {})
outputs = {k.lower(): v for k, v in t.get("outputs", {}).items()}
sas = [r for r in t.get("resources", []) if r.get("type") == "Microsoft.Storage/storageAccounts"]

def resolve(expr):
    if not isinstance(expr, str):
        return ""
    def sub(m):
        v = variables.get(m.group(1), "")
        return v.strip("[]") if isinstance(v, str) else ""
    return re.sub(r"variables\('([^']+)'\)", sub, expr)

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
check("account name comes from the storageAccountName parameter",
      "parameters('storageaccountname')" in resolve(sa.get("name", "")).lower())
check("kind StorageV2", sa.get("kind") == "StorageV2")
check("SKU Standard_GZRS (geo-zone-redundant)",
      sa.get("sku", {}).get("name") == "Standard_GZRS")
out = outputs.get("skuname", {})
check("output 'skuName' carries the account's SKU name",
      "sku.name" in str(out.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
