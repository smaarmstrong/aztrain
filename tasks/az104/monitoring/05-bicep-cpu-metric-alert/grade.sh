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
variables = t.get("variables", {})
outputs = {k.lower(): v for k, v in t.get("outputs", {}).items()}
alerts = [r for r in t.get("resources", [])
          if r.get("type") == "Microsoft.Insights/metricAlerts"]

def resolve(expr):
    if not isinstance(expr, str):
        return ""
    def sub(m):
        v = variables.get(m.group(1), "")
        return v.strip("[]") if isinstance(v, str) else ""
    return re.sub(r"variables\('([^']+)'\)", sub, expr).lower()

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("exactly one metricAlerts resource", len(alerts) == 1)
a = alerts[0] if alerts else {}
props = a.get("properties", {})

scopes = props.get("scopes", [])
check("scopes targets the vmResourceId parameter",
      any("parameters('vmresourceid')" in resolve(s) for s in scopes))
check("severity is 2", props.get("severity") == 2)
check("alert is enabled", props.get("enabled") is True)

allof = props.get("criteria", {}).get("allOf", [])
check("exactly one criterion under criteria.allOf", len(allof) == 1)
c = allof[0] if allof else {}
check("criterion metricName is 'Percentage CPU'", c.get("metricName") == "Percentage CPU")
check("criterion operator is GreaterThan", c.get("operator") == "GreaterThan")
check("criterion threshold is 80", str(c.get("threshold")) == "80")
check("criterion timeAggregation is Average", c.get("timeAggregation") == "Average")

actions = props.get("actions", [])
check("an action wires the actionGroupId parameter",
      any("parameters('actiongroupid')" in resolve(x.get("actionGroupId", ""))
          for x in actions))

out = outputs.get("alertid", {})
check("output 'alertId' carries the alert resource id",
      "resourceid" in str(out.get("value", "")).lower()
      or "metricalerts" in str(out.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
