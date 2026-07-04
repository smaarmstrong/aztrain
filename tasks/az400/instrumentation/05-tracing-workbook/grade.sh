#!/usr/bin/env bash
# Parse the learner's Azure Monitor workbook JSON and assert its structure.
# Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WB="$AZTRAIN_WS/workbook.json"
check_eval "workbook.json exists in your workspace" '[ -f "$WB" ]'

python3 - "$WB" <<'EOF'
import json, sys

try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ workbook.json is not valid JSON ({e})")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + cond, fail + (not cond)

check("workbook has a version", bool(doc.get("version")))
items = doc.get("items", [])
check("workbook has an items array", isinstance(items, list) and len(items) >= 1)

# a workbook query tile: type 3 with a KqlItem content carrying a query string
def query_of(it):
    c = it.get("content", {}) if isinstance(it, dict) else {}
    if it.get("type") == 3 and "query" in c:
        return str(c.get("query", ""))
    return None

queries = [q for q in (query_of(it) for it in items) if q]
check("workbook has at least one KQL query tile (type 3)", len(queries) >= 1)

# text tile giving the workbook context (type 1)
check("workbook has a text/markdown tile (type 1)",
      any(isinstance(it, dict) and it.get("type") == 1 for it in items))

blob = "\n".join(queries).lower()
# distributed tracing lives in the dependency telemetry table
check("a query inspects dependency telemetry (AppDependencies)",
      "appdependencies" in blob)
# tracing correlates requests and dependencies by operation
check("a query correlates traces (OperationId or a join across telemetry)",
      "operationid" in blob or "join" in blob)
# queries should be time-bounded like real Application Insights queries
check("a query is time-scoped (ago / TimeGenerated)",
      "ago(" in blob or "timegenerated" in blob)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workbook satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
