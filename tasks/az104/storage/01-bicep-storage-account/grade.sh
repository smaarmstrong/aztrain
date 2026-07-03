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
variables = t.get("variables", {})
outputs = {k.lower(): v for k, v in t.get("outputs", {}).items()}
sas = [r for r in t.get("resources", []) if r.get("type") == "Microsoft.Storage/storageAccounts"]

def resolve(expr):
    """Inline one level of variables() so 'name comes from the parameter'
    passes however the learner plumbed it."""
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
    ok, fail = ok + cond, fail + (not cond)

p = params.get("storageaccountname", {})
check("parameter 'storageAccountName' (string)", p.get("type", "").lower() == "string")
loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))
check("exactly one storage account resource", len(sas) == 1)
sa = sas[0] if sas else {}
props = sa.get("properties", {})
check("account name comes from the storageAccountName parameter",
      "parameters('storageaccountname')" in resolve(sa.get("name", "")).lower())
check("account location comes from the location parameter",
      "parameters('location')" in resolve(sa.get("location", "")).lower())
check("kind StorageV2", sa.get("kind") == "StorageV2")
check("SKU Standard_LRS", sa.get("sku", {}).get("name") == "Standard_LRS")
check("minimum TLS version TLS1_2", props.get("minimumTlsVersion") == "TLS1_2")
check("blob public access disabled", props.get("allowBlobPublicAccess") is False)
check("HTTPS-only enforced", props.get("supportsHttpsTrafficOnly") is True)
out = outputs.get("blobendpoint", {})
check("output 'blobEndpoint' carries the primary blob endpoint",
      "primaryendpoints.blob" in str(out.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
