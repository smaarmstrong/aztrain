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
vms = [r for r in res if r.get("type") == "Microsoft.Compute/virtualMachines"]
nics = [r for r in res if r.get("type") == "Microsoft.Network/networkInterfaces"]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("parameter 'vmName' (string)", params.get("vmname", {}).get("type", "").lower() == "string")
check("secure parameter 'adminPublicKey'",
      params.get("adminpublickey", {}).get("type", "").lower() == "securestring")
loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))
check("a network interface resource exists", len(nics) >= 1)
check("exactly one virtual machine resource", len(vms) == 1)

vm = vms[0] if vms else {}
props = vm.get("properties", {})
check("VM size is Standard_B1s",
      props.get("hardwareProfile", {}).get("vmSize") == "Standard_B1s")
osdisk = props.get("storageProfile", {}).get("osDisk", {})
check("OS disk uses managed disk Standard_LRS",
      osdisk.get("managedDisk", {}).get("storageAccountType") == "Standard_LRS")
lin = props.get("osProfile", {}).get("linuxConfiguration", {})
check("password authentication disabled",
      lin.get("disablePasswordAuthentication") is True)
keydata = str(lin.get("ssh", {}).get("publicKeys", [{}])[0].get("keyData", ""))
check("SSH public key wired from the adminPublicKey parameter",
      "parameters('adminPublicKey')" in keydata)
vm_nics = props.get("networkProfile", {}).get("networkInterfaces", [])
check("VM is attached to a network interface",
      isinstance(vm_nics, list) and len(vm_nics) >= 1
      and "networkinterfaces" in str(vm_nics[0].get("id", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
