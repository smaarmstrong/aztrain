#!/usr/bin/env bash
# Parse the Dependabot config and assert dependency scanning is configured.
# Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

YML="$AZTRAIN_WS/dependabot.yml"
check_eval "dependabot.yml exists in your workspace" '[ -f "$YML" ]'
if [ ! -f "$YML" ]; then grade_summary; exit $?; fi

if ! python3 -c "import sys; sys.path.insert(0,'$AZTRAIN_REPO/tools'); import yamlmini as y; y.load_file('$YML')" 2>/dev/null; then
  check_eval "dependabot.yml parses as YAML" 'false'
  grade_summary; exit $?
fi
check_eval "dependabot.yml parses as YAML" 'true'

python3 - "$AZTRAIN_REPO" "$YML" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

d = y.load_file(sys.argv[2])
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("config is Dependabot version 2", y.dig(d, "version") == 2)

updates = y.dig(d, "updates")
check("has an updates list with at least one entry",
      isinstance(updates, list) and len(updates) > 0)
updates = updates if isinstance(updates, list) else []

VALID_ECO = {"npm", "pip", "nuget", "github-actions", "docker", "maven",
             "gradle", "gomod", "bundler", "composer", "cargo", "mix",
             "pub", "terraform", "devcontainers", "pipenv", "poetry", "uv"}

good = None
for u in updates:
    if not isinstance(u, dict):
        continue
    eco = str(u.get("package-ecosystem", "")).lower()
    has_dir = bool(str(u.get("directory", "")).strip()) or bool(u.get("directories"))
    interval = str(y.dig(u, "schedule", "interval") or "").lower()
    if eco in VALID_ECO and has_dir and interval in {"daily", "weekly", "monthly", "cron"}:
        good = u
        break

check("an entry names a valid package-ecosystem", good is not None)
check("that entry sets a directory", good is not None and (
      bool(str(good.get("directory", "")).strip()) or bool(good.get("directories"))))
check("that entry sets a schedule interval",
      good is not None and str(y.dig(good, "schedule", "interval") or "").lower()
      in {"daily", "weekly", "monthly", "cron"})

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "Dependabot dependency scanning is configured" '[ "$PY_RC" -eq 0 ]'
grade_summary
