#!/usr/bin/env bash
# Order: wait for running jobs -> stop protection and delete backup data -> delete the vault -> delete the group.
# Soft delete is always on for vaults, so the first run usually keeps the vault for 14 days (free).
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
rm -f "$(dirname "$0")/policy.json"
backup_cleanup "$RG" "$VAULT" "$VM"
case $? in
  0) az group delete --name "$RG" --yes --no-wait
     echo "Resource group deletion started. Check in 10 minutes: az group exists -n $RG" ;;
  2) delete_all_but_vault "$RG"
     finish_vault_cleanup "$RG" "$VAULT" ;;
  *) echo "Cleanup stopped. Read the error above, fix it, and run ./cleanup.sh again." >&2; exit 1 ;;
esac
echo "Azure Backup may also have created an empty, free group AzureBackupRG_${LOC}_1. Delete it when you finish all labs:"
echo "  az group delete -n AzureBackupRG_${LOC}_1 --yes"
