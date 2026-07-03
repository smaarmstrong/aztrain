#!/usr/bin/env bash
# Provision the broken starting state. Idempotent; creates ONLY inside $AZTRAIN_RG.
# Cost: resource groups and NSGs are free.
set -euo pipefail
. "$AZTRAIN_REPO/lib/common.sh"

ensure_rg

az network nsg create -g "$AZTRAIN_RG" -n nsg-web -o none

# Recreate the "security sweep" deny rule; drop any rules a previous attempt added.
for rule in $(az network nsg rule list -g "$AZTRAIN_RG" --nsg-name nsg-web \
              --query "[].name" -o tsv); do
  az network nsg rule delete -g "$AZTRAIN_RG" --nsg-name nsg-web -n "$rule" -o none
done
az network nsg rule create -g "$AZTRAIN_RG" --nsg-name nsg-web \
  -n lockdown-web --priority 200 --direction Inbound --access Deny \
  --protocol Tcp --destination-port-ranges 80 443 \
  --source-address-prefixes Internet --destination-address-prefixes '*' -o none
