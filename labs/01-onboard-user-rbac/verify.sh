#!/usr/bin/env bash
# Lab 01 checks
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab01"
GROUP="grp-finance-readers"
require_login
UPN="priya.lab01@$(tenant_domain)"

say "Checking lab 01"
check "user $UPN exists" az ad user show --id "$UPN"
GROUP_ID="$(az ad group show --group "$GROUP" --query id -o tsv 2>/dev/null)"
USER_ID="$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null)"
expect "user is a member of $GROUP" \
  "$(az ad group member check --group "$GROUP_ID" --member-id "$USER_ID" --query value -o tsv 2>/dev/null)" "true"

RG_ID="$(az group show --name "$RG" --query id -o tsv 2>/dev/null)"
expect "group has Reader on $RG" \
  "$(az role assignment list --scope "$RG_ID" --assignee "$GROUP_ID" --query "[?roleDefinitionName=='Reader'] | length(@)" -o tsv 2>/dev/null)" "1"
expect "user has NO direct role assignment on $RG (access comes from the group)" \
  "$(az role assignment list --scope "$RG_ID" --assignee "$USER_ID" --query "length(@)" -o tsv 2>/dev/null)" "0"
summary
