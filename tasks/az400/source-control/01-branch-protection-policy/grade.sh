#!/usr/bin/env bash
# Parse the learner's branch protection ruleset (stdlib json) and assert the
# policy it expresses. Read-only. Any structurally-correct ruleset passes.
. "$AZTRAIN_REPO/lib/common.sh"

RULESET="$AZTRAIN_WS/ruleset.json"

check_eval "ruleset.json exists in your workspace" '[ -f "$RULESET" ]'
if [ ! -f "$RULESET" ]; then grade_summary; exit $?; fi
check_eval "ruleset.json is valid JSON" 'python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$RULESET"'

python3 - "$RULESET" <<'EOF'
import json, sys

try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ could not parse JSON: {e}")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("enforcement is active", str(d.get("enforcement", "")).lower() == "active")
check("target is a branch", str(d.get("target", "")).lower() == "branch")

# conditions target the default branch (either the ~DEFAULT_BRANCH alias or main)
include = d.get("conditions", {}).get("ref_name", {}).get("include", [])
inc_txt = " ".join(str(x).lower() for x in include) if isinstance(include, list) else str(include).lower()
check("conditions target the default branch (~DEFAULT_BRANCH or refs/heads/main)",
      "~default_branch" in inc_txt or "refs/heads/main" in inc_txt or inc_txt.strip() == "main")

rules = d.get("rules", [])
check("rules is a non-empty array", isinstance(rules, list) and len(rules) > 0)
by_type = {}
for r in rules:
    if isinstance(r, dict) and "type" in r:
        by_type[str(r["type"]).lower()] = r

# 1. pull requests required with >= 1 approving review
pr = by_type.get("pull_request", {})
prc = pr.get("parameters", {}).get("required_approving_review_count")
check("a pull_request rule requires >= 1 approving review",
      isinstance(prc, int) and prc >= 1)

# 2. required status checks with at least one check, including 'build'
sc = by_type.get("required_status_checks", {})
checks = sc.get("parameters", {}).get("required_status_checks", [])
contexts = []
if isinstance(checks, list):
    for c in checks:
        if isinstance(c, dict) and "context" in c:
            contexts.append(str(c["context"]).lower())
        elif isinstance(c, str):
            contexts.append(c.lower())
check("required_status_checks lists at least one check", len(contexts) >= 1)
check("a 'build' status check is required", "build" in contexts)

# 3. force pushes / history rewrites blocked
check("force pushes blocked (non_fast_forward rule present)",
      "non_fast_forward" in by_type)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "ruleset expresses the required protection policy" '[ "$PY_RC" -eq 0 ]'
grade_summary
