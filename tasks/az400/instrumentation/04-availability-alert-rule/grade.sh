#!/usr/bin/env bash
# Parse the learner's metric alert JSON and assert its criteria. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

ALERT="$AZTRAIN_WS/alert.json"
check_eval "alert.json exists in your workspace" '[ -f "$ALERT" ]'

python3 - "$ALERT" <<'EOF'
import json, sys

try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ alert.json is not valid JSON ({e})")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + cond, fail + (not cond)

check("resource type is Microsoft.Insights/metricAlerts",
      doc.get("type", "").lower() == "microsoft.insights/metricalerts")
props = doc.get("properties", {})
check("alert is enabled", props.get("enabled") is True)

sev = props.get("severity")
check("severity is high (Sev0/1/2)", isinstance(sev, int) and 0 <= sev <= 2)

# evaluation window: fire over a 5-minute window
def norm(v):
    return str(v).upper().replace(" ", "")
check("windowSize is a 5-minute window (PT5M)", norm(props.get("windowSize")) == "PT5M")
check("evaluationFrequency is set (ISO-8601 duration)",
      norm(props.get("evaluationFrequency", "")).startswith("PT"))

# scope must target an Application Insights component
scopes = " ".join(str(s) for s in props.get("scopes", []))
check("alert is scoped to an Application Insights component",
      "microsoft.insights/components" in scopes.lower())

crit = props.get("criteria", {})
conds = crit.get("allOf", [])
check("criteria has at least one condition", len(conds) >= 1)

# find a condition on failed requests, > threshold, aggregated as a Total count
def is_failed_metric(c):
    return "failed" in str(c.get("metricName", "")).lower()
fc = next((c for c in conds if is_failed_metric(c)), None)
check("a condition watches the failed-requests metric", fc is not None)
fc = fc or {}
check("operator is GreaterThan (alert when failures exceed a threshold)",
      str(fc.get("operator", "")).lower() == "greaterthan")
th = fc.get("threshold")
check("threshold is a positive number",
      isinstance(th, (int, float)) and not isinstance(th, bool) and th > 0)
check("timeAggregation counts failures over the window (Total)",
      str(fc.get("timeAggregation", "")).lower() == "total")

# it must notify someone
actions = props.get("actions", [])
has_ag = any(a.get("actionGroupId") for a in actions if isinstance(a, dict))
check("alert notifies an action group (actions[].actionGroupId)", has_ag)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "metric alert satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
