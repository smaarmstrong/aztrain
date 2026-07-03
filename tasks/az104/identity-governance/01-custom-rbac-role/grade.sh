#!/usr/bin/env bash
# Parse the learner's custom-role JSON and assert the effective permission set.
# Read-only; no subscription touched.
. "$AZTRAIN_REPO/lib/common.sh"

ROLE="$AZTRAIN_WS/role.json"
check_eval "role.json exists in your workspace" '[ -f "$ROLE" ]'
[ -f "$ROLE" ] || { grade_summary; exit $?; }

python3 - "$ROLE" <<'EOF'
import json, sys, fnmatch

try:
    r = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ role.json is valid JSON ({e})")
    sys.exit(1)

# case-insensitive key lookup so "actions"/"Actions" both work
low = {k.lower(): v for k, v in r.items()} if isinstance(r, dict) else {}
actions   = [a for a in low.get("actions", []) if isinstance(a, str)]
notactions= [a for a in low.get("notactions", []) if isinstance(a, str)]
scopes    = [s for s in low.get("assignablescopes", []) if isinstance(s, str)]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def granted(op):
    """True if `op` is granted by Actions AND not removed by NotActions,
    honouring '*' wildcards (as Azure RBAC does)."""
    g = any(fnmatch.fnmatchcase(op.lower(), pat.lower()) for pat in actions)
    if not g:
        return False
    removed = any(fnmatch.fnmatchcase(op.lower(), pat.lower()) for pat in notactions)
    return not removed

name = low.get("name")
desc = low.get("description")
check("Name is a non-empty string", isinstance(name, str) and name.strip() != "")
check("Description is a non-empty string", isinstance(desc, str) and desc.strip() != "")
check("IsCustom is true", low.get("iscustom") is True)

for op in [
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    "Microsoft.Compute/virtualMachines/powerOff/action",
    "Microsoft.Insights/metrics/read",
]:
    check(f"grants {op}", granted(op))

for op in [
    "Microsoft.Compute/virtualMachines/delete",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/delete",
]:
    check(f"does NOT grant {op}", not granted(op))

check("AssignableScopes has at least one /subscriptions/... entry",
      any(s.startswith("/subscriptions/") for s in scopes))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "role.json satisfies the least-privilege spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
