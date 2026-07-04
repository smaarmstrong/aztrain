#!/usr/bin/env bash
# Parse the learner's workflow YAML and assert the OIDC + Key Vault shape.
# Read-only: never touches a subscription.
. "$AZTRAIN_REPO/lib/common.sh"

YML="$AZTRAIN_WS/deploy.yml"
check_eval "deploy.yml exists in your workspace" '[ -f "$YML" ]'
if [ ! -f "$YML" ]; then grade_summary; exit $?; fi

if ! python3 -c "import sys; sys.path.insert(0,'$AZTRAIN_REPO/tools'); import yamlmini as y; y.load_file('$YML')" 2>/dev/null; then
  check_eval "deploy.yml parses as YAML" 'false'
  grade_summary; exit $?
fi
check_eval "deploy.yml parses as YAML" 'true'

python3 - "$AZTRAIN_REPO" "$YML" <<'EOF'
import sys, re
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

d = y.load_file(sys.argv[2])
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

def walk_strings(obj):
    if isinstance(obj, dict):
        for v in obj.values():
            yield from walk_strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from walk_strings(v)
    elif isinstance(obj, str):
        yield obj

# id-token: write may sit at top level or inside the job.
perms_top = y.dig(d, "permissions", "id-token")
perms_job = y.dig(d, "jobs", "deploy", "permissions", "id-token")
check("job has 'id-token: write' permission for OIDC",
      str(perms_top).lower() == "write" or str(perms_job).lower() == "write")

check("deploy job runs on an Ubuntu runner",
      "ubuntu" in str(y.dig(d, "jobs", "deploy", "runs-on")).lower())

steps = y.dig(d, "jobs", "deploy", "steps") or []
check("deploy job has a steps list", isinstance(steps, list) and len(steps) > 0)

login = None
for s in steps:
    if isinstance(s, dict) and "azure/login" in str(s.get("uses", "")):
        login = s
        break
check("a step uses azure/login", login is not None)

with_ = (login or {}).get("with", {}) if isinstance(login, dict) else {}
if not isinstance(with_, dict):
    with_ = {}
check("azure/login supplies a client-id", bool(str(with_.get("client-id", "")).strip()))
check("azure/login supplies a tenant-id", bool(str(with_.get("tenant-id", "")).strip()))
check("azure/login supplies a subscription-id", bool(str(with_.get("subscription-id", "")).strip()))
# Secretless: no creds / client-secret input on the login step.
keys = {k.lower() for k in with_.keys()}
check("azure/login uses OIDC (no 'creds' or 'client-secret' input)",
      "creds" not in keys and "client-secret" not in keys and "clientsecret" not in keys)

# Key Vault fetch: either the action or an `az keyvault secret show` script.
kv_action = any(
    isinstance(s, dict) and "get-keyvault-secrets" in str(s.get("uses", ""))
    for s in steps
)
kv_script = any(
    isinstance(s, dict) and re.search(r"az\s+keyvault\s+secret\s+(show|list|download)",
                                       str(s.get("run", "")))
    for s in steps
)
check("a step fetches the secret from Key Vault (action or 'az keyvault secret show')",
      kv_action or kv_script)

# No plaintext connection string / inline secret anywhere in the file.
leaked = False
for s in walk_strings(d):
    low = s.lower()
    if ("password=" in low and "${{" not in s) or ("accountkey=" in low):
        leaked = True
check("no plaintext connection string / secret in the file", not leaked)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the OIDC + Key Vault spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
