#!/usr/bin/env bash
# Reference fix: allow HTTPS at a higher priority than the blanket deny.
# (Equally valid: narrow lockdown-web to port 80 only.)
set -euo pipefail

az network nsg rule create -g "$AZTRAIN_RG" --nsg-name nsg-web \
  -n allow-https --priority 100 --direction Inbound --access Allow \
  --protocol Tcp --destination-port-ranges 443 \
  --source-address-prefixes Internet --destination-address-prefixes '*' -o none
