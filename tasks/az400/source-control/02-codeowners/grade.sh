#!/usr/bin/env bash
# Parse the learner's CODEOWNERS and assert the required path->owner mappings
# and valid syntax. Read-only. Any reasonable owners are accepted.
. "$AZTRAIN_REPO/lib/common.sh"

CO="$AZTRAIN_WS/CODEOWNERS"

check_eval "CODEOWNERS exists in your workspace" '[ -f "$CO" ]'
if [ ! -f "$CO" ]; then grade_summary; exit $?; fi

python3 - "$CO" <<'EOF'
import re, sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()

OWNER = re.compile(r"^(@[A-Za-z0-9](?:[A-Za-z0-9._-]*)(?:/[A-Za-z0-9._-]+)?|[^@\s]+@[^@\s]+\.[^@\s]+)$")

rules = []          # (pattern, [owners])
syntax_ok = True
bad_line = None
for raw in lines:
    line = raw.split("#", 1)[0].strip()
    if not line:
        continue
    parts = line.split()
    pattern, owners = parts[0], parts[1:]
    if not owners:
        syntax_ok = False
        bad_line = raw.strip()
        continue
    if not all(OWNER.match(o) for o in owners):
        syntax_ok = False
        bad_line = raw.strip()
        continue
    rules.append((pattern, owners))

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("at least one rule parsed", len(rules) > 0)
if not syntax_ok:
    print(f"    (offending line: {bad_line!r})")
check("every rule has a pattern and valid owner(s)", syntax_ok)

def has(pred):
    return any(pred(p) for p, _ in rules)

check("catch-all rule '*' with a default owner", has(lambda p: p == "*"))
check("/infra/ mapped to an owner",
      has(lambda p: p.rstrip("/*") in ("/infra", "infra") or p in ("/infra/", "infra/")))
check("*.tf mapped to an owner", has(lambda p: p == "*.tf" or p.endswith("/*.tf")))
check("/docs/ mapped to an owner",
      has(lambda p: p.rstrip("/*") in ("/docs", "docs") or p in ("/docs/", "docs/")))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "CODEOWNERS routes reviews to the required owners" '[ "$PY_RC" -eq 0 ]'
grade_summary
