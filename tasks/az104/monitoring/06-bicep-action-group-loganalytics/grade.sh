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
res = t.get("resources", [])
wss = [r for r in res if r.get("type") == "Microsoft.OperationalInsights/workspaces"]
ags = [r for r in res if r.get("type") == "Microsoft.Insights/actionGroups"]

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

loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))

check("exactly one Log Analytics workspace", len(wss) == 1)
ws = wss[0] if wss else {}
wp = ws.get("properties", {})
check("workspace name comes from the workspaceName parameter",
      "parameters('workspacename')" in resolve(ws.get("name", "")))
check("workspace SKU is PerGB2018", wp.get("sku", {}).get("name") == "PerGB2018")
check("workspace retentionInDays is 90", str(wp.get("retentionInDays")) == "90")

check("exactly one action group", len(ags) == 1)
ag = ags[0] if ags else {}
ap = ag.get("properties", {})
sn = ap.get("groupShortName", "")
check("groupShortName present and <= 12 chars",
      isinstance(sn, str) and 0 < len(sn) <= 12)
check("action group enabled", ap.get("enabled") is True)
ers = ap.get("emailReceivers", [])
check("exactly one email receiver", len(ers) == 1)
er = ers[0] if ers else {}
check("email receiver address comes from the opsEmail parameter",
      "parameters('opsemail')" in resolve(er.get("emailAddress", "")))

wout = outputs.get("workspaceid", {})
check("output 'workspaceId' carries the workspace resource id",
      "workspaces" in str(wout.get("value", "")).lower())
aout = outputs.get("actiongroupid", {})
check("output 'actionGroupId' carries the action group resource id",
      "actiongroups" in str(aout.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
