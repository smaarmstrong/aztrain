#!/usr/bin/env bash
# Provision the broken starting state. Idempotent; creates ONLY inside $AZTRAIN_RG.
# Cost: resource groups, VNets, subnets and route tables are all free.
set -euo pipefail
. "$AZTRAIN_REPO/lib/common.sh"

ensure_rg

# Route table with a black-hole default route, created before the subnet so it
# can be associated at subnet-create time.
az network route-table create -g "$AZTRAIN_RG" -n rt-web -o none

# Reset the default route to the black-hole state (drop any prior fix attempt).
az network route-table route create -g "$AZTRAIN_RG" --route-table-name rt-web \
  -n default --address-prefix 0.0.0.0/0 --next-hop-type None -o none 2>/dev/null \
  || az network route-table route update -g "$AZTRAIN_RG" --route-table-name rt-web \
       -n default --address-prefix 0.0.0.0/0 --next-hop-type None -o none

# VNet + web subnet, subnet associated with the (broken) route table.
az network vnet create -g "$AZTRAIN_RG" -n vnet-app \
  --address-prefixes 10.40.0.0/16 -o none
az network vnet subnet create -g "$AZTRAIN_RG" --vnet-name vnet-app -n snet-web \
  --address-prefixes 10.40.1.0/24 --route-table rt-web -o none
