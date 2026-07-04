#!/usr/bin/env bash
# Structurally grade passwordless OIDC login to Azure. Read-only + inspection.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/deploy.yml"
check_eval "deploy.yml exists in your workspace" '[ -f "$WF" ]'
check_eval "deploy.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$WF" >/dev/null'
# Inspection: the old stored-credential blob must be gone entirely.
check_eval "no stored-credential 'creds:' blob remains" \
  '! grep -qE "^\s*creds\s*:" "$WF"'

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

# GitHub needs id-token: write to mint the federated OIDC token.
check("permissions grants id-token: write",
      str(y.dig(d, "permissions", "id-token") or "") == "write")

# Find the azure/login step across whichever job holds it.
login = None
for job in (y.dig(d, "jobs") or {}).values():
    for step in (y.dig(job, "steps") or []):
        if isinstance(step, dict) and "azure/login" in str(step.get("uses", "")):
            login = step
            break
check("a step uses azure/login", login is not None)
w = (login or {}).get("with", {}) if isinstance((login or {}).get("with", {}), dict) else {}
for field in ("client-id", "tenant-id", "subscription-id"):
    check(f"azure/login provides {field}", bool(str(w.get(field, "")).strip()))
check("azure/login does NOT pass a stored 'creds' credential",
      "creds" not in w)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow logs in to Azure passwordlessly via OIDC" '[ "$PY_RC" -eq 0 ]'
grade_summary
