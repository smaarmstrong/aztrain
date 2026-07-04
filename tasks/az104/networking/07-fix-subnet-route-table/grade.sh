#!/usr/bin/env bash
# Read-only: assert the subnet's route table sends its default route to the
# Internet next hop (and stays associated). Asserts END STATE, not commands.
. "$AZTRAIN_REPO/lib/common.sh"

# 1) The route table is still associated with the web subnet.
check_eval "route table 'rt-web' is associated with subnet 'snet-web'" \
  'az network vnet subnet show -g "$AZTRAIN_RG" --vnet-name vnet-app -n snet-web \
     --query "routeTable.id" -o tsv 2>/dev/null | grep -qi "/rt-web$"'

# 2) The default route (0.0.0.0/0) resolves to the Internet next hop.
ROUTES=$(mktemp)
trap 'rm -f "$ROUTES"' EXIT
az network route-table route list -g "$AZTRAIN_RG" --route-table-name rt-web \
  -o json > "$ROUTES" 2>/dev/null

check_eval "route table 'rt-web' has readable routes" '[ -s "$ROUTES" ]'
check_eval "the 0.0.0.0/0 route's next hop is Internet (no longer a black hole)" \
  'python3 -c "
import json, sys
routes = json.load(open(\"$ROUTES\"))
default = [r for r in routes if r.get(\"addressPrefix\") == \"0.0.0.0/0\"]
sys.exit(0 if default and all(r.get(\"nextHopType\") == \"Internet\" for r in default) else 1)
"'

grade_summary
