#!/usr/bin/env bash
# Compile the learner's Bicep and assert the file share + quota. Read-only.
. "$AZTRAIN_REPO/lib/common.sh"

BICEP="$AZTRAIN_WS/main.bicep"
COMPILED=$(mktemp)
trap 'rm -f "$COMPILED"' EXIT

check_eval "main.bicep exists in your workspace" '[ -f "$BICEP" ]'
if ! bicep_build "$BICEP" > "$COMPILED" 2>/dev/null || [ ! -s "$COMPILED" ]; then
  check_eval "main.bicep compiles (az bicep build)" 'false'
  grade_summary; exit $?
fi
check_eval "main.bicep compiles (az bicep build)" 'true'

python3 - "$COMPILED" <<'EOF'
import json, re, sys

t = json.load(open(sys.argv[1]))
params = {k.lower(): v for k, v in t.get("parameters", {}).items()}
resources = t.get("resources", [])

def by_type(tp):
    return [r for r in resources if r.get("type") == tp]

def name_segments(name):
    if not isinstance(name, str):
        return []
    inner = name.strip().lstrip("[").rstrip("]").strip()
    m = re.match(r"format\(\s*'([^']*)'\s*,\s*(.*)\)$", inner)
    if not m:
        return inner.strip("'").split("/")
    tmpl, rest = m.group(1), m.group(2)
    args, depth, cur = [], 0, ""
    for ch in rest:
        if ch == "(":
            depth += 1; cur += ch
        elif ch == ")":
            depth -= 1; cur += ch
        elif ch == "," and depth == 0:
            args.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip():
        args.append(cur.strip())
    lits = []
    for a in args:
        lm = re.fullmatch(r"'([^']*)'", a)
        lits.append(lm.group(1) if lm else None)
    segs = []
    for tok in tmpl.split("/"):
        im = re.fullmatch(r"\{(\d+)\}", tok.strip())
        if im:
            idx = int(im.group(1))
            segs.append(lits[idx] if idx < len(lits) else None)
        else:
            segs.append(tok.strip())
    return segs

ok = fail = 0
def check(desc, cond):
    global ok, fail
    print(f"  {'✓' if cond else '✗'} {desc}")
    ok, fail = ok + bool(cond), fail + (not cond)

p = params.get("storageaccountname", {})
check("parameter 'storageAccountName' (string)", p.get("type", "").lower() == "string")
loc = params.get("location", {})
check("parameter 'location' defaults to resourceGroup().location",
      "resourceGroup().location" in str(loc.get("defaultValue", "")))

sas = by_type("Microsoft.Storage/storageAccounts")
check("a StorageV2 / Standard_LRS storage account",
      len(sas) == 1 and sas[0].get("kind") == "StorageV2"
      and sas[0].get("sku", {}).get("name") == "Standard_LRS")

fsvc = by_type("Microsoft.Storage/storageAccounts/fileServices")
check("a fileServices resource named 'default'",
      any(name_segments(r.get("name", ""))[-1:] == ["default"] for r in fsvc))

shares = by_type("Microsoft.Storage/storageAccounts/fileServices/shares")
finance = [r for r in shares if name_segments(r.get("name", ""))[-1:] == ["finance"]]
check("a file share named 'finance'", len(finance) >= 1)
check("share 'finance' has a shareQuota of 100",
      any(r.get("properties", {}).get("shareQuota") == 100 for r in finance))

sys.exit(1 if fail else 0)
EOF
PY_RC=$?
check_eval "compiled template satisfies the spec" '[ "$PY_RC" -eq 0 ]'
grade_summary
