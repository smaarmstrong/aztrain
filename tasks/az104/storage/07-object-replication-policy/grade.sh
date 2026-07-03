#!/usr/bin/env bash
# Parse the learner's object replication policy JSON and assert structure. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

POLICY="$AZTRAIN_WS/or-policy.json"

check_eval "or-policy.json exists in your workspace" '[ -f "$POLICY" ]'

python3 - "$POLICY" <<'EOF'
import json, sys

try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ or-policy.json is valid JSON (parse error: {e})")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

if not isinstance(doc, dict):
    check("policy is a JSON object", False)
    sys.exit(1)

check("has a 'sourceAccount' field", "sourceAccount" in doc)
check("has a 'destinationAccount' field", "destinationAccount" in doc)

rules = doc.get("rules")
check("'rules' array with at least one rule",
      isinstance(rules, list) and len(rules) > 0)
rules = rules if isinstance(rules, list) else []

def rule_ok(r):
    return (isinstance(r, dict)
            and r.get("sourceContainer") == "uploads"
            and r.get("destinationContainer") == "uploads-replica")

match = [r for r in rules if rule_ok(r)]
check("a rule maps sourceContainer 'uploads' -> destinationContainer 'uploads-replica'",
      len(match) >= 1)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "policy satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
