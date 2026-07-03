#!/usr/bin/env bash
# Grades the safety-rail bootstrap. READ-ONLY, like every grader.
. "$AZTRAIN_REPO/lib/common.sh"

PIN_FILE="${AZTRAIN_PIN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/aztrain/subscription}"
PIN=$(grep -v '^#' "$PIN_FILE" 2>/dev/null | grep -m1 . | tr -d '[:space:]')
ACTIVE=$(az account show --query id -o tsv 2>/dev/null)

check_eval "pin file exists ($PIN_FILE)" '[ -n "$PIN" ]'
check_eval "pin is a subscription GUID" \
  'echo "$PIN" | grep -qiE "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"'
check_eval "logged in to az" '[ -n "$ACTIVE" ]'
check_eval "active subscription == pinned subscription" \
  '[ -n "$PIN" ] && [ "${ACTIVE,,}" = "${PIN,,}" ]'

AMOUNT=$(az consumption budget list --query \
  "[?name=='aztrain-budget'] | [0].amount" -o tsv 2>/dev/null)
check_eval "budget 'aztrain-budget' exists" '[ -n "$AMOUNT" ]'
check_eval "budget amount is 10 or less (got: ${AMOUNT:-none})" \
  '[ -n "$AMOUNT" ] && [ "$(printf "%.0f" "$AMOUNT")" -le 10 ]'

SP_ID=$(az ad sp list --display-name aztrain-sp --query "[0].id" -o tsv 2>/dev/null)
ON_SUB=0; WIDER=checkfailed
if [ -n "$SP_ID" ] && [ -n "$ACTIVE" ]; then
  SCOPES=$(az role assignment list --all --assignee "$SP_ID" --query "[].scope" -o tsv 2>/dev/null)
  ON_SUB=$(echo "$SCOPES" | grep -cie "^/subscriptions/$ACTIVE")
  WIDER=$(echo "$SCOPES" | grep -e . | grep -vice "^/subscriptions/$ACTIVE")
fi
check_eval "service principal 'aztrain-sp' exists" '[ -n "$SP_ID" ]'
check_eval "aztrain-sp has a role assignment on this subscription" '[ "$ON_SUB" -ge 1 ]'
check_eval "aztrain-sp has NO role assignment outside this subscription" '[ "$WIDER" = "0" ]'

grade_summary
