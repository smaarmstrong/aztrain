#!/usr/bin/env bash
# Provision a web app WITHOUT a managed identity. Idempotent; creates ONLY
# inside $AZTRAIN_RG. Cost: the F1 (Free) App Service tier is free.
set -euo pipefail
. "$AZTRAIN_REPO/lib/common.sh"

ensure_rg

# App Service (web app) names form a global DNS label, so derive a stable,
# RG-unique one. The plan itself is free on the F1 tier. Managed identity is a
# control-plane (Entra) feature and free; if a future F1 policy ever rejects
# `identity assign`, bump --sku to B1 (pennies) — the task is otherwise
# unchanged.
SUFFIX=$(printf '%s' "$AZTRAIN_RG" | md5sum | cut -c1-10)
PLAN="plan-noidentity"
APP="web-noid-${SUFFIX}"

az appservice plan create -g "$AZTRAIN_RG" -n "$PLAN" \
  --sku F1 --is-linux -o none

az webapp create -g "$AZTRAIN_RG" -p "$PLAN" -n "$APP" \
  --runtime "PYTHON:3.12" -o none

# Ensure we start from a clean, identity-less state even on a re-run.
az webapp identity remove -g "$AZTRAIN_RG" -n "$APP" --yes -o none 2>/dev/null || true
