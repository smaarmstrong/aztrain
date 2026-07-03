#!/usr/bin/env bash
# Parse the learner's lifecycle policy JSON and assert its structure. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

POLICY="$AZTRAIN_WS/policy.json"

check_eval "policy.json exists in your workspace" '[ -f "$POLICY" ]'

python3 - "$POLICY" <<'EOF'
import json, sys

try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ policy.json is valid JSON (parse error: {e})")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

rules = doc.get("rules") if isinstance(doc, dict) else None
check("top-level 'rules' array", isinstance(rules, list) and len(rules) > 0)
rules = rules or []

# Find an enabled Lifecycle rule whose baseBlob actions we can inspect.
def base_actions(rule):
    if not isinstance(rule, dict):
        return None
    if rule.get("type") != "Lifecycle":
        return None
    if rule.get("enabled") is not True:
        return None
    return rule.get("definition", {})

lifecycle = [r for r in rules if base_actions(r) is not None]
check("an enabled rule of type 'Lifecycle'", len(lifecycle) > 0)

# From here on, pick a rule that has the tier+delete actions we need.
def days(action):
    if not isinstance(action, dict):
        return None
    return action.get("daysAfterModificationGreaterThan")

chosen = None
for r in lifecycle:
    d = r.get("definition", {})
    base = d.get("actions", {}).get("baseBlob", {})
    if days(base.get("tierToCool")) == 30 and days(base.get("delete")) == 365:
        chosen = r
        break
if chosen is None:
    # fall back to any lifecycle rule so remaining checks report usefully
    chosen = lifecycle[0] if lifecycle else {}

d = chosen.get("definition", {})
filt = d.get("filters", {})
blob_types = filt.get("blobTypes", [])
check("filter targets block blobs (blobTypes includes blockBlob)",
      isinstance(blob_types, list) and "blockBlob" in blob_types)

base = d.get("actions", {}).get("baseBlob", {})
check("tierToCool at daysAfterModificationGreaterThan == 30",
      days(base.get("tierToCool")) == 30)
check("delete at daysAfterModificationGreaterThan == 365",
      days(base.get("delete")) == 365)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "policy satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
