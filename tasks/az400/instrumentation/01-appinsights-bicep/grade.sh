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
resources = t.get("resources", [])
comps = [r for r in resources if r.get("type") == "Microsoft.Insights/components"]
wss = [r for r in resources if r.get("type") == "Microsoft.OperationalInsights/workspaces"]

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

check("exactly one Log Analytics workspace", len(wss) == 1)
check("exactly one Application Insights component", len(comps) == 1)
comp = comps[0] if comps else {}
ws = wss[0] if wss else {}
props = comp.get("properties", {})

check("component kind is 'web'", comp.get("kind") == "web")
check("component Application_Type is 'web'", props.get("Application_Type") == "web")

# workspace-based: WorkspaceResourceId must reference the workspace resource
wref = resolve(str(props.get("WorkspaceResourceId", "")))
check("component is workspace-based (WorkspaceResourceId set)",
      bool(props.get("WorkspaceResourceId")))
check("WorkspaceResourceId points at the Log Analytics workspace",
      "microsoft.operationalinsights/workspaces" in wref.lower())

# the component must depend on / follow the workspace
dep = " ".join(resolve(str(x)).lower() for x in comp.get("dependsOn", []))
check("component references the workspace (dependsOn or resourceId)",
      "microsoft.operationalinsights/workspaces" in (dep + wref.lower()))

out = outputs.get("connectionstring", {})
check("output 'connectionString' carries the component connection string",
      "connectionstring" in str(out.get("value", "")).lower())

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
