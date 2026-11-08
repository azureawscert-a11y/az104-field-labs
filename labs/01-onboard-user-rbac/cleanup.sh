#!/usr/bin/env bash
# Lab 01 cleanup: role assignment, user, group, resource group
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab01"
GROUP="grp-finance-readers"
require_login
UPN="priya.lab01@$(tenant_domain)"

GROUP_ID="$(az ad group show --group "$GROUP" --query id -o tsv 2>/dev/null || true)"
RG_ID="$(az group show --name "$RG" --query id -o tsv 2>/dev/null || true)"
if [[ -n "$GROUP_ID" && -n "$RG_ID" ]]; then
  az role assignment delete --assignee "$GROUP_ID" --role "Reader" --scope "$RG_ID" || true
fi
az ad user delete --id "$UPN" 2>/dev/null || true
if [[ -n "$GROUP_ID" ]]; then az ad group delete --group "$GROUP_ID" || true; fi
if [[ -n "$RG_ID" ]]; then
  az group delete --name "$RG" --yes --no-wait || echo "Group delete failed. Read the error above and run ./cleanup.sh again." >&2
fi
echo "Cleanup started. Deleted users stay in Entra ID > Deleted users for 30 days (you can restore them)."
