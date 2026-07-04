#!/usr/bin/env bash
# Structurally grade a reusable YAML template + its reference. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

PIPE="$AZTRAIN_WS/azure-pipelines.yml"
TMPL="$AZTRAIN_WS/templates/build-job.yml"
check_eval "azure-pipelines.yml exists in your workspace" '[ -f "$PIPE" ]'
check_eval "templates/build-job.yml exists in your workspace" '[ -f "$TMPL" ]'
check_eval "azure-pipelines.yml parses as YAML (yamlmini)" \
  'python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$PIPE" >/dev/null'
check_eval "templates/build-job.yml parses as YAML (yamlmini)" \
  '[ -f "$TMPL" ] && python3 "$AZTRAIN_REPO/tools/yamlmini.py" "$TMPL" >/dev/null'

python3 - "$AZTRAIN_REPO" "$PIPE" "$TMPL" <<'EOF'
import os
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import yamlmini as y

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

try:
    main = y.load_file(sys.argv[2])
except Exception as e:
    print(f"  ✗ azure-pipelines.yml parse error: {e}")
    sys.exit(1)

tmpl_path = sys.argv[3]
tmpl = None
if os.path.isfile(tmpl_path):
    try:
        tmpl = y.load_file(tmpl_path)
    except Exception as e:
        print(f"  ✗ templates/build-job.yml parse error: {e}")

def param_names(node):
    """parameters: may be a list of {name: x} or a mapping {x: default}."""
    params = y.dig(node or {}, "parameters")
    if isinstance(params, list):
        return {str(p.get("name")) for p in params if isinstance(p, dict) and p.get("name")}
    if isinstance(params, dict):
        return {str(k) for k in params}
    return set()

# --- the template declares and uses buildConfiguration ---
check("template declares a 'buildConfiguration' parameter",
      "buildConfiguration" in param_names(tmpl))
check("template has a steps: list", isinstance(y.dig(tmpl or {}, "steps"), list))
tmpl_text = open(tmpl_path).read() if os.path.isfile(tmpl_path) else ""
check("template uses ${{ parameters.buildConfiguration }}",
      "parameters.buildConfiguration" in tmpl_text.replace(" ", ""))

# --- the main pipeline references the template and passes the parameter ---
def find_template_refs(obj):
    refs = []
    if isinstance(obj, dict):
        if "template" in obj:
            refs.append(obj)
        for v in obj.values():
            refs.extend(find_template_refs(v))
    elif isinstance(obj, list):
        for v in obj:
            refs.extend(find_template_refs(v))
    return refs

refs = find_template_refs(main)
build_refs = [r for r in refs if "build-job.yml" in str(r.get("template", ""))]
check("main pipeline references templates/build-job.yml via '- template:'",
      len(build_refs) >= 1)
passes_param = any(
    "buildConfiguration" in (y.dig(r, "parameters") or {})
    for r in build_refs
)
check("the template reference passes a buildConfiguration parameter",
      passes_param)

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "template extraction satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
