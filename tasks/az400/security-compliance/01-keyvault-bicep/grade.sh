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
vaults = [r for r in t.get("resources", []) if r.get("type") == "Microsoft.KeyVault/vaults"]

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
    ok, fail = ok + cond, fail + (not cond)

p = params.get("keyvaultname", {})
check("parameter 'keyVaultName' (string)", p.get("type", "").lower() == "string")
loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))
tid = params.get("tenantid", {})
check("parameter 'tenantId' defaults to subscription().tenantId",
      "subscription().tenantId" in str(tid.get("defaultValue", "")))
check("exactly one Key Vault resource", len(vaults) == 1)
v = vaults[0] if vaults else {}
props = v.get("properties", {})
check("vault name comes from the keyVaultName parameter",
      "parameters('keyvaultname')" in resolve(v.get("name", "")).lower())
check("vault location comes from the location parameter",
      "parameters('location')" in resolve(v.get("location", "")).lower())
check("tenantId comes from the tenantId parameter",
      "parameters('tenantid')" in resolve(props.get("tenantId", "")).lower())
sku = props.get("sku", {})
check("SKU family A, name standard",
      str(sku.get("family")).lower() == "a" and str(sku.get("name")).lower() == "standard")
check("RBAC authorization enabled", props.get("enableRbacAuthorization") is True)
check("soft-delete enabled", props.get("enableSoftDelete") is True)
check("soft-delete retention is 90 days", props.get("softDeleteRetentionInDays") == 90)
check("purge protection enabled", props.get("enablePurgeProtection") is True)
acls = props.get("networkAcls", {})
check("network default action is Deny", str(acls.get("defaultAction")).lower() == "deny")
check("network bypass is AzureServices", str(acls.get("bypass")).lower() == "azureservices")
out = outputs.get("vaulturi", {})
check("output 'vaultUri' carries the vault URI",
      "vaulturi" in str(out.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
