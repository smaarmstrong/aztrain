#!/usr/bin/env bash
# Compile the learner's Bicep and assert the CanNotDelete lock on the account. Read-only.
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

sas = [r for r in res if r.get("type") == "Microsoft.Storage/storageAccounts"]
# A lock can appear either as Microsoft.Authorization/locks with a `scope`,
# or as a nested type ".../storageAccounts/providers/locks".
locks = [r for r in res
         if r.get("type") == "Microsoft.Authorization/locks"
         or r.get("type", "").lower().endswith("/providers/locks")]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("parameter 'storageAccountName' (string)",
      params.get("storageaccountname", {}).get("type", "").lower() == "string")

check("exactly one storage account resource", len(sas) == 1)
sa = sas[0] if sas else {}
check("account named from storageAccountName parameter",
      "parameters('storageAccountName')" in str(sa.get("name", "")))
check("kind StorageV2", sa.get("kind") == "StorageV2")
check("SKU Standard_LRS", sa.get("sku", {}).get("name") == "Standard_LRS")

check("exactly one lock resource", len(locks) == 1)
lk = locks[0] if locks else {}
check("lock level is CanNotDelete",
      lk.get("properties", {}).get("level") == "CanNotDelete")

# Scoped to the account: either an explicit `scope` referencing it, or a
# nested-type lock whose name/type is prefixed by the account.
blob = json.dumps(lk)
scoped = ("parameters('storageAccountName')" in blob
          and ("Microsoft.Storage/storageAccounts" in blob))
check("lock is scoped to the storage account", scoped)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the lock spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
