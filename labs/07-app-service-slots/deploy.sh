#!/usr/bin/env bash
# Lab 07: Release version 2 with zero downtime using a staging slot and a swap.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab07"
PLAN="asp-lab07-s1"
require_login
APP="app-lab07-$(suffix)"
TMP="$(mktemp -d)"

say "1. Windows App Service plan S1 (Standard is the lowest tier with deployment slots)"
# Newer Azure CLI versions create LINUX plans by default, so ask for Windows explicitly.
az group create --name "$RG" --location "$LOC" --tags lab=07 -o none
az appservice plan create --name "$PLAN" --resource-group "$RG" --location "$LOC" --sku S1 --is-linux false -o none

say "2. Web app (Windows plan, serves a static index.html)"
az webapp create --name "$APP" --resource-group "$RG" --plan "$PLAN" -o none
az webapp update --name "$APP" --resource-group "$RG" --https-only true -o none

say "3. Version 1 to production"
echo '<h1 style="font-family:sans-serif;color:#1d6bf3">Version 1 (production)</h1>' > "$TMP/index.html"
az webapp deploy --name "$APP" --resource-group "$RG" --src-path "$TMP/index.html" \
  --type static --target-path index.html -o none

say "4. Staging slot with version 2"
az webapp deployment slot create --name "$APP" --resource-group "$RG" --slot staging -o none
echo '<h1 style="font-family:sans-serif;color:#15803d">Version 2 (new release)</h1>' > "$TMP/index.html"
az webapp deploy --name "$APP" --resource-group "$RG" --slot staging --src-path "$TMP/index.html" \
  --type static --target-path index.html -o none

say "5. A slot-sticky setting: stays with the slot, does NOT move on swap"
az webapp config appsettings set --name "$APP" --resource-group "$RG" --slot staging \
  --slot-settings ENVIRONMENT=staging -o none
az webapp config appsettings set --name "$APP" --resource-group "$RG" \
  --slot-settings ENVIRONMENT=production -o none

echo
echo "Production: https://$APP.azurewebsites.net"
echo "Staging:    https://$APP-staging.azurewebsites.net"
echo "Open both, then swap:"
echo "  az webapp deployment slot swap --name $APP --resource-group $RG --slot staging --target-slot production"
echo "Then run ./verify.sh"
