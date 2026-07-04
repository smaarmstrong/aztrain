#!/usr/bin/env bash
# Assert an Azure DevOps service-hook subscription that POSTs build events to a
# webhook endpoint, with no inline credential. JSON parsed with stdlib. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

CFG="$AZTRAIN_WS/servicehook.json"
check_eval "servicehook.json exists in your workspace" '[ -f "$CFG" ]'
if [ ! -f "$CFG" ]; then grade_summary; exit $?; fi

check_eval "servicehook.json is valid JSON" \
  'python3 -c "import json,sys; json.load(open(\"$CFG\"))"'

python3 - "$CFG" <<'EOF'
import json, sys, re

d = json.load(open(sys.argv[1]))
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

ci = d.get("consumerInputs", {}) if isinstance(d.get("consumerInputs"), dict) else {}
pi = d.get("publisherInputs", {}) if isinstance(d.get("publisherInputs"), dict) else {}

# The consumer is the generic Web Hooks HTTP consumer (not e.g. a Slack app).
check("uses the generic 'webHooks' consumer",
      str(d.get("consumerId", "")).lower() == "webhooks")
check("consumer action posts an HTTP request",
      str(d.get("consumerActionId", "")).lower() == "httprequest")

# It subscribes to a real event type (build/release/workitem/pullrequest/...).
et = str(d.get("eventType", ""))
check("subscribes to an event type", bool(et) and "." in et)

# It targets a webhook URL over HTTPS.
url = str(ci.get("url", ""))
check("posts to an https webhook URL", url.startswith("https://"))

# No inline secret: any auth header must reference a variable/secret, not a
# literal token. Accept $(VAR) or ${{ }} style indirection; reject long
# base64-ish literals or 'Bearer <literal>'.
headers = str(ci.get("httpHeaders", "")) + str(ci.get("basicAuthPassword", ""))
def has_inline_secret(s):
    # a literal bearer/token/password value that is NOT a variable reference
    for m in re.finditer(r"(?i)(bearer|token|password|apikey|api-key)[:=\s]+(\S+)", s):
        val = m.group(2)
        if val.startswith("$(") or val.startswith("${{") or val.startswith("$"):
            continue
        if len(val) >= 12:
            return True
    return False

check("no inline auth secret (credentials referenced indirectly)",
      not has_inline_secret(headers))
# and if an auth header is present at all, it must use indirection
if headers.strip():
    check("auth header uses a variable/secret reference",
          ("$(" in headers) or ("${{" in headers))
else:
    # no auth header is also acceptable (endpoint may be pre-authorized)
    check("auth header uses a variable/secret reference", True)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "service-hook config satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
