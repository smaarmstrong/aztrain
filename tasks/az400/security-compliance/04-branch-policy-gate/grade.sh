#!/usr/bin/env bash
# Parse the branch-protection JSON and assert the merge gate. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

JSON="$AZTRAIN_WS/protection.json"
check_eval "protection.json exists in your workspace" '[ -f "$JSON" ]'
if [ ! -f "$JSON" ]; then grade_summary; exit $?; fi

if ! python3 -c "import json,sys; json.load(open('$JSON'))" 2>/dev/null; then
  check_eval "protection.json is valid JSON" 'false'
  grade_summary; exit $?
fi
check_eval "protection.json is valid JSON" 'true'

python3 - "$JSON" <<'EOF'
import json, sys

d = json.load(open(sys.argv[1]))
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

# 1. Required PR reviews
rpr = d.get("required_pull_request_reviews")
check("pull request reviews are required (object present)", isinstance(rpr, dict))
rpr = rpr if isinstance(rpr, dict) else {}
try:
    count = int(rpr.get("required_approving_review_count", 0))
except (TypeError, ValueError):
    count = 0
check("at least one approving review required", count >= 1)
check("dismiss_stale_reviews is true", rpr.get("dismiss_stale_reviews") is True)

# 2. Required status checks incl. a code-scanning context
rsc = d.get("required_status_checks")
check("status checks are required (object present)", isinstance(rsc, dict))
rsc = rsc if isinstance(rsc, dict) else {}
check("status checks are strict", rsc.get("strict") is True)

names = []
for c in (rsc.get("contexts") or []):
    if isinstance(c, str):
        names.append(c)
for c in (rsc.get("checks") or []):
    if isinstance(c, dict) and "context" in c:
        names.append(str(c["context"]))
    elif isinstance(c, str):
        names.append(c)
blob = " ".join(names).lower()
check("a code-scanning / CodeQL status check is required",
      "codeql" in blob or "code-scanning" in blob or "code scanning" in blob)

# 3. Admins included
check("rule is enforced for admins", d.get("enforce_admins") is True)

# 4. Force-push and deletion blocked
check("force pushes are disallowed", d.get("allow_force_pushes") is False)
check("branch deletions are disallowed", d.get("allow_deletions") is False)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "branch protection satisfies the gate" '[ "$PY_RC" -eq 0 ]'
grade_summary
