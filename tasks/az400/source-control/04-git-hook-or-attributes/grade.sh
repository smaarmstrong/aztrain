#!/usr/bin/env bash
# Parse the learner's .gitattributes and assert the line-ending / LFS policy.
# Read-only; the file is parsed directly.
. "$AZTRAIN_REPO/lib/common.sh"

GA="$AZTRAIN_WS/.gitattributes"

check_eval ".gitattributes exists in your workspace" '[ -f "$GA" ]'
if [ ! -f "$GA" ]; then grade_summary; exit $?; fi

python3 - "$GA" <<'EOF'
import sys

rules = {}   # pattern -> set of attribute tokens (lowercased)
for raw in open(sys.argv[1], encoding="utf-8").read().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split()
    if len(parts) < 2:
        continue
    pat, attrs = parts[0], [a.lower() for a in parts[1:]]
    rules.setdefault(pat, set()).update(attrs)

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

check("at least one attribute rule parsed", len(rules) > 0)
check("every parsed rule has a pattern and an attribute", all(rules.values()))

# 1. default text normalization
star = rules.get("*", set())
check("default '* text=auto' normalizes line endings", "text=auto" in star)

# 2. shell scripts forced to LF
sh = rules.get("*.sh", set())
check("*.sh forced to LF (text eol=lf)", "eol=lf" in sh and ("text" in sh or "text=auto" in sh))

# 3. a true binary marked binary (accept the 'binary' macro or -text -diff)
png = rules.get("*.png", set())
check("*.png marked as binary",
      "binary" in png or ("-text" in png and "-diff" in png))

# 4. large assets routed to LFS
psd = rules.get("*.psd", set())
check("*.psd tracked by Git LFS (filter/diff/merge=lfs)",
      "filter=lfs" in psd and "diff=lfs" in psd and "merge=lfs" in psd)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval ".gitattributes implements the line-ending and LFS policy" '[ "$PY_RC" -eq 0 ]'
grade_summary
