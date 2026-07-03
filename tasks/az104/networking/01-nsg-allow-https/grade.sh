#!/usr/bin/env bash
# Read-only: fetch the NSG's rules, then assert BEHAVIOUR via nsgsim.
. "$AZTRAIN_REPO/lib/common.sh"

RULES=$(mktemp)
trap 'rm -f "$RULES"' EXIT
az network nsg show -g "$AZTRAIN_RG" -n nsg-web --query securityRules -o json > "$RULES" 2>/dev/null

check_eval "NSG 'nsg-web' exists with readable rules" '[ -s "$RULES" ]'
check_eval "inbound TCP 443 from the Internet is ALLOWED" \
  'python3 "$AZTRAIN_REPO/tools/nsgsim.py" "$RULES" --direction Inbound --protocol Tcp --port 443 --source Internet'
check_eval "inbound TCP 80 from the Internet is still DENIED" \
  '! python3 "$AZTRAIN_REPO/tools/nsgsim.py" "$RULES" --direction Inbound --protocol Tcp --port 80 --source Internet'

grade_summary
