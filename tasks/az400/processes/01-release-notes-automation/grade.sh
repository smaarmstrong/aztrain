#!/usr/bin/env bash
# Assert the release-notes workflow: tag/release trigger + a job that builds
# notes from Git history and publishes them. Structure only — any correct
# workflow shape passes. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

WF="$AZTRAIN_WS/release-notes.yml"
check_eval "release-notes.yml exists in your workspace" '[ -f "$WF" ]'
if [ ! -f "$WF" ]; then grade_summary; exit $?; fi

check_eval "release-notes.yml parses as YAML" \
  'python3 -c "import sys; sys.path.insert(0,\"$AZTRAIN_REPO/tools\"); import yamlmini as y; y.load_file(\"$WF\")"'

python3 - "$WF" <<'EOF'
import sys
sys.path.insert(0, __import__("os").environ["AZTRAIN_REPO"] + "/tools")
import yamlmini as y

d = y.load_file(sys.argv[1])
ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

# 'on:' may parse as the string key "on" (yamlmini does not coerce keys).
trig = y.dig(d, "on") or y.dig(d, True)

def tag_or_release_trigger(t):
    if not isinstance(t, dict):
        return False
    # tag push...
    tags = y.dig(t, "push", "tags")
    if tags:  # any non-empty tag filter
        return True
    # ...or a release event
    if "release" in t:
        return True
    return False

check("triggers on a tag push or a release event", tag_or_release_trigger(trig))

jobs = y.dig(d, "jobs")
check("defines at least one job", isinstance(jobs, dict) and len(jobs) >= 1)

# Find a job whose steps generate notes from git history and publish them.
def steps_of(job):
    s = y.dig(job, "steps")
    return s if isinstance(s, list) else []

def text_of_step(st):
    parts = []
    for k in ("run", "uses", "name"):
        v = y.dig(st, k)
        if isinstance(v, str):
            parts.append(v)
    return "\n".join(parts).lower()

gen_ok = pub_ok = False
if isinstance(jobs, dict):
    for job in jobs.values():
        for st in steps_of(job):
            t = text_of_step(st)
            if "git log" in t or "git-cliff" in t or "conventional" in t or "changelog" in t or "release notes" in t or "release-notes" in t:
                gen_ok = True
            if "gh-release" in t or "gh release" in t or "create-release" in t or "createrelease" in t or "softprops" in t or "release@" in t:
                pub_ok = True

check("a step generates notes/changelog from Git history", gen_ok)
check("a step publishes a GitHub Release / tag with those notes", pub_ok)

# checkout with full history is what makes git-log-based notes correct
deep = False
if isinstance(jobs, dict):
    for job in jobs.values():
        for st in steps_of(job):
            if "checkout" in str(y.dig(st, "uses") or "").lower():
                if str(y.dig(st, "with", "fetch-depth")) == "0":
                    deep = True
check("checkout fetches full history (fetch-depth: 0)", deep)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "workflow satisfies the release-notes spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
