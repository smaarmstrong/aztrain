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

vmss = of_type("Microsoft.Compute/virtualMachineScaleSets")
autos = of_type("Microsoft.Insights/autoscaleSettings")

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(params.get("location", {}).get("defaultValue", "")))
check("a scale set on Standard_B1s exists",
      any(v.get("sku", {}).get("name") == "Standard_B1s" for v in vmss))
check("exactly one autoscaleSettings resource", len(autos) == 1)

a = autos[0] if autos else {}
props = a.get("properties", {})
check("autoscale is enabled", props.get("enabled") is True)
check("targetResourceUri references a scale set",
      "virtualmachinescalesets" in str(props.get("targetResourceUri", "")).lower())

profiles = props.get("profiles", [])
check("at least one autoscale profile", len(profiles) >= 1)
p = profiles[0] if profiles else {}
cap = p.get("capacity", {})
check("capacity minimum is 2", str(cap.get("minimum")) == "2")
check("capacity maximum is 10", str(cap.get("maximum")) == "10")
check("capacity default is 2", str(cap.get("default")) == "2")

rules = p.get("rules", [])
cpu_out = False
for r in rules:
    mt = r.get("metricTrigger", {})
    sa = r.get("scaleAction", {})
    if (str(mt.get("metricName", "")).lower() == "percentage cpu"
            and str(sa.get("direction", "")).lower() == "increase"
            and str(sa.get("type", "")).lower() == "changecount"):
        cpu_out = True
check("a CPU-based scale-out rule (Percentage CPU, Increase, ChangeCount)",
      cpu_out)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
