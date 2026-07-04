#!/usr/bin/env bash
# Grade OIDC/service-connection auth with NO inline secrets. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

PIPE="$AZTRAIN_WS/azure-pipelines.yml"
check_eval "azure-pipelines.yml exists in your workspace" '[ -f "$PIPE" ]'
check_eval "azure-pipelines.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$PIPE" >/dev/null'

python3 - "$AZTRAIN_REPO" "$PIPE" <<'EOF'
import re
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

try:
    d = y.load_file(sys.argv[2])
except Exception as e:
    print(f"  ✗ parse error: {e}")
    sys.exit(1)

text = open(sys.argv[2]).read()

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

# find all steps anywhere in the doc
def all_steps(obj):
    steps = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "steps" and isinstance(v, list):
                steps.extend(s for s in v if isinstance(s, dict))
            else:
                steps.extend(all_steps(v))
    elif isinstance(obj, list):
        for v in obj:
            steps.extend(all_steps(v))
    return steps

steps = all_steps(d)
azcli = [s for s in steps if str(s.get("task", "")).startswith("AzureCLI@")]
check("an AzureCLI@2 task is present", len(azcli) >= 1)

with_conn = [s for s in azcli
             if str(y.dig(s, "inputs", "azureSubscription") or "").strip()]
check("the AzureCLI task authenticates via a service connection (azureSubscription)",
      len(with_conn) >= 1)

# --- inspection: no inline credentials ---
low = text.lower()
check("no 'az login' with an inline password/service-principal secret",
      not re.search(r"az\s+login\b.*(-p\b|--password\b|--client-secret\b)", low))
check("no clientSecret / client-secret key with a value",
      not re.search(r"client[-_]?secret\s*[:=]\s*\S", low))
check("no storage AccountKey= literal",
      "accountkey=" not in low)
check("no obvious hardcoded password value",
      not re.search(r"\bpassword\s*[:=]\s*[\"']?\S{6,}", low))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "secretless deployment satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
