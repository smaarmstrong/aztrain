#!/usr/bin/env bash
# Assert the learner's .gitignore excludes the required secret/build patterns
# and is not over-broad. Read-only; the file is parsed directly.
. "$AZTRAIN_REPO/lib/common.sh"

GI="$AZTRAIN_WS/.gitignore"

check_eval ".gitignore exists in your workspace" '[ -f "$GI" ]'
if [ ! -f "$GI" ]; then grade_summary; exit $?; fi

python3 - "$GI" <<'EOF'
import sys

pats = []
for raw in open(sys.argv[1], encoding="utf-8").read().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    pats.append(line)

norm = [p.lstrip("/").rstrip("/") for p in pats]

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("at least one ignore pattern present", len(pats) > 0)

# not over-broad: reject a bare catch-all that would hide the whole tree
overbroad = {"*", "**", "*.*", "**/*", "."}
bad = [p for p in pats if p in overbroad or p.rstrip("/") in {"", "/"}]
if bad:
    print(f"    (over-broad pattern(s): {bad})")
check("does not ignore the whole tree (no bare '*'/'**' catch-all)", not bad)

def matches_env(p):
    return p in ("*.env", ".env", ".env.*") or p.endswith("/.env") or p.endswith("/*.env") or p.endswith(".env")
check("ignores dotenv/secret files (*.env)", any(matches_env(p) for p in norm))
check("ignores certificate material (*.pfx)",
      any(p == "*.pfx" or p.endswith("/*.pfx") or p.endswith(".pfx") for p in norm))
check("ignores node_modules/",
      any(p == "node_modules" or p.endswith("/node_modules") for p in norm))
check("ignores build output (bin/)",
      any(p == "bin" or p.endswith("/bin") for p in norm))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval ".gitignore excludes the required patterns without over-ignoring" '[ "$PY_RC" -eq 0 ]'
grade_summary
