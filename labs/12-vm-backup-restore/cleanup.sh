#!/usr/bin/env bash
# A vault cannot be deleted while it still holds protected items.
# Order: wait for running jobs -> stop protection and delete backup data -> delete vault -> delete the group.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
if ! backup_cleanup "$RG" "$VAULT" "$VM"; then
  echo "Cleanup stopped so you are not billed for a vault you think is gone. Read the error above." >&2
  exit 1
fi
az group delete --name "$RG" --yes --no-wait
rm -f "$(dirname "$0")/policy.json"
echo "Vault removed and resource group deletion started. Check in 10 minutes: az group exists -n $RG"
echo "Azure Backup may also have created an empty, free group AzureBackupRG_${LOC}_1. Delete it when you finish all labs:"
echo "  az group delete -n AzureBackupRG_${LOC}_1 --yes"
