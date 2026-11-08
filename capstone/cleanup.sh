#!/usr/bin/env bash
# Order matters: lock -> backup data -> vault -> policies -> resource group -> Entra group.
# Soft delete is always on for vaults, so the first run usually keeps the vault for 14 days (free).
set -uo pipefail
# shellcheck source=SCRIPTDIR/../common/lib.sh
source "$(dirname "$0")/../common/lib.sh"
RG="rg-az104-capstone"
if az group show -n "$RG" -o none 2>/dev/null; then
  az lock delete --name lock-capstone --resource-group "$RG" || true
  backup_cleanup "$RG" rsv-nwclinic vm-app01; RC=$?
  [[ $RC -eq 1 ]] && { echo "Cleanup stopped. Read the error above, fix it, and run ./cleanup.sh again." >&2; exit 1; }
  RG_ID="$(az group show -n "$RG" --query id -o tsv)"
  # Remove the policy identity's role assignment first, or it is left behind as "Identity not found"
  PID="$(az policy assignment show --name cap-inherit-costcenter --scope "$RG_ID" --query identity.principalId -o tsv 2>/dev/null || true)"
  if [[ -n "$PID" ]]; then az role assignment delete --assignee "$PID" --scope "$RG_ID" || true; fi
  az policy assignment delete --name cap-inherit-costcenter --scope "$RG_ID" || true
  az policy assignment delete --name cap-allowed-locations --scope "$RG_ID" || true
  if [[ $RC -eq 0 ]]; then
    delete_group "$RG" || exit 1
  else
    delete_all_but_vault "$RG" || exit 1
    finish_vault_cleanup "$RG" rsv-nwclinic
  fi
fi
OPS_ID="$(lab_group_id grp-clinic-ops)" || exit 1
if [[ -n "$OPS_ID" ]]; then
  # If the resource group is still there (vault kept by soft delete), remove the group's role assignment
  # first, or it would be left behind as "Identity not found".
  RG_ID="$(az group show -n "$RG" --query id -o tsv 2>/dev/null || true)"
  if [[ -n "$RG_ID" ]]; then az role assignment delete --assignee-object-id "$OPS_ID" --scope "$RG_ID" 2>/dev/null || true; fi
  az ad group delete --group "$OPS_ID" || exit 1
fi
echo "Check in 10 minutes: az group exists -n $RG"
echo "Azure Backup keeps VM snapshots in AzureBackupRG_${LOC}_1 (the capstone's were deleted above)."
echo "When you finish all labs and nothing else in this region is backed up, delete that group:"
echo "  az group delete -n AzureBackupRG_${LOC}_1 --yes"
echo "NetworkWatcherRG is free and shared by your subscription: you can leave it."
