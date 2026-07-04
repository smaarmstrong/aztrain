#!/usr/bin/env bash
# Reference fix: point the default route at the Internet next hop.
# (Equally valid: delete + recreate the route, as long as 0.0.0.0/0 -> Internet
# and rt-web stays associated with snet-web.)
set -euo pipefail

az network route-table route update -g "$AZTRAIN_RG" --route-table-name rt-web \
  -n default --address-prefix 0.0.0.0/0 --next-hop-type Internet -o none
