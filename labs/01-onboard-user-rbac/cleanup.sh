#!/usr/bin/env bash
# Lab 01 cleanup: role assignment, user, group, resource group
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab01"
GROUP="grp-finance-readers"
require_login
UPN="priya.lab01@$(tenant_domain)"

GROUP_ID="$(group_id_exact "$GROUP")" || exit 1
RG_ID="$(az group show --name "$RG" --query id -o tsv 2>/dev/null || true)"
if [[ -n "$GROUP_ID" && -n "$RG_ID" ]]; then
  az role assignment delete --assignee "$GROUP_ID" --role "Reader" --scope "$RG_ID" || true
fi
FAILED=0
if az ad user show --id "$UPN" -o none 2>/dev/null; then az ad user delete --id "$UPN" || FAILED=1; fi
if [[ -n "$GROUP_ID" ]]; then az ad group delete --group "$GROUP_ID" || FAILED=1; fi
delete_group "$RG" || FAILED=1
echo "Deleted users stay in Entra ID > Deleted users for 30 days (you can restore them)."
[[ $FAILED -eq 0 ]] || { echo "Some cleanup steps failed. Read the errors above and run ./cleanup.sh again." >&2; exit 1; }
