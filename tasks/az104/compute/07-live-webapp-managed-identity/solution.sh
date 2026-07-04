#!/usr/bin/env bash
# Reference fix: turn on the system-assigned managed identity.
# (Equally valid: enable it in the portal, or via a Bicep redeploy.)
set -euo pipefail

APP=$(az webapp list -g "$AZTRAIN_RG" --query "[0].name" -o tsv)

az webapp identity assign -g "$AZTRAIN_RG" -n "$APP" -o none
