#!/usr/bin/env bash
# Structurally grade a gated deploy (needs + environment). Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/release.yml"
check_eval "release.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "release.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$WF" >/dev/null'

python3 - "$AZTRAIN_REPO" "$WF" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

try:
    d = y.load_file(sys.argv[2])
except Exception as e:
    print(f"  ✗ parse error: {e}")
    sys.exit(1)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

jobs = y.dig(d, "jobs") or {}
check("a 'build' job exists", isinstance(y.dig(jobs, "build"), dict))

deploy = y.dig(jobs, "deploy")
check("a 'deploy' job exists", isinstance(deploy, dict))
deploy = deploy if isinstance(deploy, dict) else {}

needs = deploy.get("needs")
needs_list = needs if isinstance(needs, list) else ([needs] if needs else [])
check("deploy depends on build via needs:", "build" in needs_list)

env = deploy.get("environment")
env_name = env if isinstance(env, str) else (y.dig(env, "name") if isinstance(env, dict) else None)
check("deploy targets a named environment", bool(env_name))
check("the environment is 'production'", env_name == "production")

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the gating spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
