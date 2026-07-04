#!/usr/bin/env bash
# SECRETS-BY-INSPECTION: fail if any hardcoded secret literal survives and
# require that secrets are referenced indirectly. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

YML="$AZTRAIN_WS/release.yml"
check_eval "release.yml exists in your workspace" '[ -f "$YML" ]'
if [ ! -f "$YML" ]; then grade_summary; exit $?; fi

# It must still be valid YAML in the supported subset.
if ! python3 -c "import sys; sys.path.insert(0,'$AZTRAIN_REPO/tools'); import yamlmini as y; y.load_file('$YML')" 2>/dev/null; then
  check_eval "release.yml parses as YAML" 'false'
  grade_summary; exit $?
fi
check_eval "release.yml parses as YAML" 'true'

python3 - "$AZTRAIN_REPO" "$YML" <<'EOF'
import sys, re
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

path = sys.argv[2]
raw = open(path, encoding="utf-8").read()
d = y.load_file(path)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

# --- structure survives ---
job = None
jobs = y.dig(d, "jobs") or {}
if isinstance(jobs, dict):
    for j in jobs.values():
        if isinstance(j, dict) and j.get("runs-on") and j.get("steps"):
            job = j
            break
check("workflow still has a job with runs-on and steps", job is not None)

# --- hardcoded secret literals (by inspection of the raw text) ---
# Ignore lines/tokens that are indirect references.
def has_literal(pattern, flags=0):
    for m in re.finditer(pattern, raw, flags):
        frag = raw[max(0, m.start() - 40): m.end() + 40]
        if "${{" in frag or "$(" in frag:
            continue  # an indirect reference, not a literal
        return True
    return False

acct_key = has_literal(r"AccountKey\s*=\s*[^;\"'\s]{8,}")
check("no storage AccountKey= literal", not acct_key)

# password/pwd/token/authToken/pat assigned an inline non-reference value
inline_secret = has_literal(
    r"(?i)(password|passwd|pwd|token|authtoken|apikey|api_key|secret|pat)\s*[:=]\s*[\"']?[^\s\"'${}()][^\s\"']{5,}"
)
check("no inline password/token/apikey literal", not inline_secret)

# GitHub-style PAT and long base64 blobs pasted verbatim
pat_like = bool(re.search(r"gh[pousr]_[A-Za-z0-9]{20,}", raw))
check("no GitHub personal access token pasted in", not pat_like)
b64_blob = has_literal(r"[A-Za-z0-9+/]{40,}={0,2}")
check("no long base64 secret blob pasted in", not b64_blob)

# --- secrets are still wired in, indirectly ---
indirect = bool(re.search(r"\$\{\{\s*secrets\.", raw)) \
    or bool(re.search(r"\$\(\s*[A-Za-z_]", raw)) \
    or ("azureKeyVault" in raw) or ("get-keyvault-secrets" in raw) \
    or ("az keyvault secret" in raw)
check("secrets are referenced indirectly (secret store / variable)", indirect)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "no leaked secrets and all values referenced indirectly" '[ "$PY_RC" -eq 0 ]'
grade_summary
