#!/usr/bin/env bash
# Read-only: find the web app in the RG and assert its managed identity.
. "$AZTRAIN_REPO/lib/common.sh"

APP=$(az webapp list -g "$AZTRAIN_RG" --query "[0].name" -o tsv 2>/dev/null)

check_eval "a web app exists in the resource group" '[ -n "$APP" ]'

IDJSON=$(mktemp)
trap 'rm -f "$IDJSON"' EXIT
az webapp identity show -g "$AZTRAIN_RG" -n "$APP" -o json > "$IDJSON" 2>/dev/null

check_eval "web app has a system-assigned managed identity" \
  'python3 -c "import json,sys; d=json.load(open(\"$IDJSON\")) if __import__(\"os\").path.getsize(\"$IDJSON\") else {}; t=str((d or {}).get(\"type\",\"\")); sys.exit(0 if \"SystemAssigned\" in t else 1)"'

check_eval "identity has a principalId (service principal exists)" \
  'python3 -c "import json,sys; d=json.load(open(\"$IDJSON\")) if __import__(\"os\").path.getsize(\"$IDJSON\") else {}; pid=(d or {}).get(\"principalId\"); sys.exit(0 if pid else 1)"'

grade_summary
