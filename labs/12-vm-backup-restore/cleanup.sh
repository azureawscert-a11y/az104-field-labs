#!/usr/bin/env bash
# Order: wait for running jobs -> stop protection and delete backup data -> delete the vault -> delete the group.
# Soft delete is always on for vaults; vault data is kept 14 days at no charge. VM snapshots are billed,
# so backup_cleanup deletes them too.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
rm -f "$(dirname "$0")/policy.json"
backup_cleanup "$RG" "$VAULT" "$VM"
case $? in
  0) delete_group "$RG" || exit 1
     echo "Check in 10 minutes: az group exists -n $RG" ;;
  2) delete_all_but_vault "$RG" || exit 1
     finish_vault_cleanup "$RG" "$VAULT" ;;
  *) echo "Cleanup stopped. Read the error above, fix it, and run ./cleanup.sh again." >&2; exit 1 ;;
esac
echo "Azure Backup keeps VM snapshots in AzureBackupRG_${LOC}_1 (the lab's were deleted above)."
echo "When you finish all labs and nothing else in this region is backed up, delete that group:"
echo "  az resource list -g AzureBackupRG_${LOC}_1 -o table   # should be empty"
echo "  az group delete -n AzureBackupRG_${LOC}_1 --yes"
