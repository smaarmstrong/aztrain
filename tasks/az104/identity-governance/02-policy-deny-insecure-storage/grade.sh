#!/usr/bin/env bash
# Parse the learner's policy definition and assert its rule/effect/target.
# Read-only; no subscription touched.
. "$AZTRAIN_REPO/lib/common.sh"

POL="$AZTRAIN_WS/policy.json"
check_eval "policy.json exists in your workspace" '[ -f "$POL" ]'
[ -f "$POL" ] || { grade_summary; exit $?; }

python3 - "$POL" <<'EOF'
import json, sys

try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ policy.json is valid JSON ({e})")
    sys.exit(1)

# Accept either a top-level rule doc or one wrapped in `properties`.
props = doc.get("properties") if isinstance(doc.get("properties"), dict) else {}
def get(key):
    if key in doc: return doc[key]
    return props.get(key)

mode = get("mode")
rule = get("policyRule") or {}
params = get("parameters") or {}

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("mode is 'Indexed'", isinstance(mode, str) and mode.lower() == "indexed")

iff = rule.get("if")
then = rule.get("then")
check("policyRule has an 'if' condition and a 'then' block",
      isinstance(iff, dict) and isinstance(then, dict))
then = then if isinstance(then, dict) else {}

# effect: literal 'deny', or a parameter reference defaulting to deny
effect = then.get("effect")
def effect_is_deny(eff):
    if isinstance(eff, str):
        e = eff.strip()
        if e.lower() == "deny":
            return True
        if e.lower().startswith("[parameters("):
            # find the referenced parameter and check its default
            import re
            m = re.search(r"parameters\(\s*['\"]([^'\"]+)['\"]\s*\)", e)
            if m:
                pd = params.get(m.group(1), {})
                dflt = pd.get("defaultValue")
                return isinstance(dflt, str) and dflt.lower() == "deny"
    return False
check("then.effect is 'deny' (or a parameter defaulting to deny)", effect_is_deny(effect))

# Walk the whole condition tree collecting field/value pairs.
def clauses(node):
    out = []
    if isinstance(node, dict):
        if "field" in node:
            out.append(node)
        for k in ("allOf", "anyOf", "not"):
            v = node.get(k)
            if isinstance(v, list):
                for c in v: out.extend(clauses(c))
            elif isinstance(v, dict):
                out.extend(clauses(v))
    return out

cl = clauses(iff if isinstance(iff, dict) else {})

def targets_type(cl):
    for c in cl:
        if str(c.get("field", "")).lower() == "type" and \
           str(c.get("equals", "")).lower() == "microsoft.storage/storageaccounts":
            return True
    return False

def targets_insecure(cl):
    alias = "microsoft.storage/storageaccounts/supportshttpstrafficonly"
    for c in cl:
        if str(c.get("field", "")).lower() == alias:
            if "equals" in c and str(c["equals"]).lower() == "false":
                return True
            if "notEquals" in c and str(c["notEquals"]).lower() == "true":
                return True
    return False

check("condition targets type Microsoft.Storage/storageAccounts", targets_type(cl))
check("condition targets supportsHttpsTrafficOnly == false (insecure)", targets_insecure(cl))
check("condition uses allOf to combine the two clauses",
      isinstance(iff, dict) and "allOf" in iff)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "policy.json is a valid deny-insecure-storage definition" '[ "$PY_RC" -eq 0 ]'
grade_summary
