#!/usr/bin/env bash
# Parse the Azure Policy JSON and assert it denies unencrypted storage.
# Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

JSON="$AZTRAIN_WS/policy.json"
check_eval "policy.json exists in your workspace" '[ -f "$JSON" ]'
if [ ! -f "$JSON" ]; then grade_summary; exit $?; fi

if ! python3 -c "import json; json.load(open('$JSON'))" 2>/dev/null; then
  check_eval "policy.json is valid JSON" 'false'
  grade_summary; exit $?
fi
check_eval "policy.json is valid JSON" 'true'

python3 - "$JSON" <<'EOF'
import json, sys

d = json.load(open(sys.argv[1]))
# Accept the definition at the root or wrapped in "properties".
props = d.get("properties", d)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("mode is Indexed", str(props.get("mode", "")).lower() == "indexed")
check("has a displayName", bool(str(props.get("displayName", "")).strip()))

rule = props.get("policyRule", {}) or {}
cond = rule.get("if", {}) or {}

# Flatten every leaf condition (allOf/anyOf/not nesting) into a list of dicts.
def leaves(node):
    out = []
    if isinstance(node, dict):
        found_group = False
        for k in ("allOf", "anyOf"):
            if k in node and isinstance(node[k], list):
                found_group = True
                for c in node[k]:
                    out.extend(leaves(c))
        if "not" in node:
            found_group = True
            out.extend(leaves(node["not"]))
        if not found_group and "field" in node:
            out.append(node)
    return out

conds = leaves(cond)

def field_val(c):
    return str(c.get("field", "")).lower()

targets_storage = any(
    field_val(c) == "type" and
    str(c.get("equals", "")).lower() == "microsoft.storage/storageaccounts"
    for c in conds
)
check("condition targets Microsoft.Storage/storageAccounts", targets_storage)

def is_insecure_check(c):
    if "supportshttpstrafficonly" not in field_val(c):
        return False
    ci = {k.lower(): v for k, v in c.items()}
    if "notequals" in ci and str(ci["notequals"]).lower() in ("true", "1"):
        return True
    if "equals" in ci and str(ci["equals"]).lower() in ("false", "0"):
        return True
    return False

check("condition inspects supportsHttpsTrafficOnly (not enabled)",
      any(is_insecure_check(c) for c in conds))

# Effect: literal Deny, or a parameter reference whose default is Deny.
then = rule.get("then", {}) or {}
effect = str(then.get("effect", ""))
deny = effect.lower() == "deny"
if not deny and "parameters(" in effect.lower():
    # find the referenced parameter name and check its defaultValue
    import re
    m = re.search(r"parameters\(\s*'([^']+)'\s*\)", effect)
    if m:
        pdef = (props.get("parameters", {}) or {}).get(m.group(1), {})
        deny = str(pdef.get("defaultValue", "")).lower() == "deny"
check("effect is Deny (literal or parameter defaulting to Deny)", deny)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "policy denies unencrypted storage accounts" '[ "$PY_RC" -eq 0 ]'
grade_summary
