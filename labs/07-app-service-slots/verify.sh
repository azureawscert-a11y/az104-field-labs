#!/usr/bin/env bash
# Lab 07 checks. Run AFTER you swap.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab07"
require_login
APP="app-lab07-$(suffix)"
say "Checking lab 07"
expect "web app is HTTPS only" \
  "$(az webapp show --name "$APP" --resource-group "$RG" --query httpsOnly -o tsv)" "true"
expect "plan tier is Standard (slots need Standard or higher)" \
  "$(az appservice plan show --name asp-lab07-s1 --resource-group "$RG" --query sku.tier -o tsv)" "Standard"
expect "staging slot exists" \
  "$(az webapp deployment slot list --name "$APP" --resource-group "$RG" --query "[?name=='staging'] | length(@)" -o tsv)" "1"
PROD="$(curl -s "https://$APP.azurewebsites.net/")"
if [[ "$PROD" == *"Version 2"* ]]; then pass "production now serves Version 2 (swap done)"; else fail "production still serves Version 1. Did you swap?"; fi
STG="$(curl -s "https://$APP-staging.azurewebsites.net/")"
if [[ "$STG" == *"Version 1"* ]]; then pass "staging now holds Version 1 (instant rollback = swap again)"; else fail "staging should hold Version 1 after a swap"; fi
expect "sticky setting stayed with production" \
  "$(az webapp config appsettings list --name "$APP" --resource-group "$RG" --query "[?name=='ENVIRONMENT'].value | [0]" -o tsv)" "production"
expect "sticky setting stayed with staging" \
  "$(az webapp config appsettings list --name "$APP" --resource-group "$RG" --slot staging --query "[?name=='ENVIRONMENT'].value | [0]" -o tsv)" "staging"
summary
