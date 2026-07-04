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
res = t.get("resources", [])
def of_type(name):
    return [r for r in res if r.get("type", "").lower() == name.lower()]

vms = of_type("Microsoft.Compute/virtualMachines")
disks = of_type("Microsoft.Compute/disks")
nics = of_type("Microsoft.Network/networkInterfaces")

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def has_zones(r):
    z = r.get("zones")
    return isinstance(z, list) and len(z) >= 1

check("a network interface resource exists", len(nics) >= 1)
check("exactly one managed disk resource", len(disks) == 1)
check("exactly one virtual machine resource", len(vms) == 1)

d = disks[0] if disks else {}
check("managed disk SKU is Standard_LRS", d.get("sku", {}).get("name") == "Standard_LRS")
check("managed disk is placed in an availability zone", has_zones(d))

vm = vms[0] if vms else {}
props = vm.get("properties", {})
check("VM size is Standard_B1s",
      props.get("hardwareProfile", {}).get("vmSize") == "Standard_B1s")
check("VM is placed in an availability zone", has_zones(vm))
datadisks = props.get("storageProfile", {}).get("dataDisks", [])
check("a data disk is attached to the VM", len(datadisks) >= 1)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
