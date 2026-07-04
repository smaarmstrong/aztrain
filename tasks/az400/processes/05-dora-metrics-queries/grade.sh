#!/usr/bin/env bash
# Assert a flow-of-work dashboard definition covering the four DORA metrics,
# each with a runnable query. JSON parsed with stdlib. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

CFG="$AZTRAIN_WS/dora-dashboard.json"
check_eval "dora-dashboard.json exists in your workspace" '[ -f "$CFG" ]'
if [ ! -f "$CFG" ]; then grade_summary; exit $?; fi

check_eval "dora-dashboard.json is valid JSON" \
  'python3 -c "import json; json.load(open(\"$CFG\"))"'

python3 - "$CFG" <<'EOF'
import json, sys, re

d = json.load(open(sys.argv[1]))
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

metrics = d.get("metrics")
check("has a 'metrics' array with at least 4 entries",
      isinstance(metrics, list) and len(metrics) >= 4)
metrics = metrics if isinstance(metrics, list) else []

# Every metric must carry a title/key and a non-trivial query string.
def qtext(m):
    q = m.get("query", "")
    return q if isinstance(q, str) else ""
def label(m):
    return (str(m.get("key", "")) + " " + str(m.get("title", "")) + " " +
            str(m.get("name", ""))).lower()

all_have_query = all(len(qtext(m).strip()) >= 10 for m in metrics) and bool(metrics)
check("every metric defines a non-empty query", all_have_query)

# The four DORA metrics must all be represented (match on label OR query text).
def matches(patterns):
    for m in metrics:
        blob = (label(m) + " " + qtext(m)).lower()
        if any(re.search(p, blob) for p in patterns):
            return True
    return False

check("covers lead time for changes",
      matches([r"lead[ _-]?time"]))
check("covers deployment frequency",
      matches([r"deploy(ment)?[ _-]?freq", r"deploys?\b.*count", r"count\(\).*deploy"]))
check("covers change failure rate",
      matches([r"(change[ _-]?)?failure[ _-]?rate", r"cfr\b", r"failurerate"]))
check("covers time to restore / recovery",
      matches([r"time[ _-]?to[ _-]?rest", r"time[ _-]?to[ _-]?recover",
               r"mttr\b", r"restore", r"recover"]))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "dashboard covers the DORA flow metrics" '[ "$PY_RC" -eq 0 ]'
grade_summary
