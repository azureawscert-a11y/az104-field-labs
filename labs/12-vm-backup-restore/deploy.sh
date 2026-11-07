#!/usr/bin/env bash
# Lab 12: Protect a VM with a custom backup policy, take a backup now. restore.sh restores the disks.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
POLICY="pol-daily-14d"
HERE="$(cd "$(dirname "$0")" && pwd)"
require_login

say "1. A small VM with a file we care about"
az group create --name "$RG" --location "$LOC" --tags lab=12 -o none
if ! az vm show -g "$RG" -n "$VM" -o none 2>/dev/null; then
  az vm create --resource-group "$RG" --name "$VM" --image Ubuntu2204 --size "$VM_SIZE" \
    --admin-username azureuser --generate-ssh-keys --public-ip-address "" \
    --os-disk-delete-option Delete --nic-delete-option Delete -o none
fi
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
  --scripts "echo 'Invoice 1042: paid' | sudo tee /home/azureuser/invoices.txt" -o none

say "2. Recovery Services vault (same region as the VM)"
az backup vault create --resource-group "$RG" --name "$VAULT" --location "$LOC" -o none
# LAB ONLY: turn soft delete off so cleanup can remove the vault today.
# In production leave soft delete ON: it protects backups from deletion for 14 days.
az backup vault backup-properties set --resource-group "$RG" --name "$VAULT" \
  --soft-delete-feature-state Disable -o none

say "3. Custom backup policy: copy DefaultPolicy, keep daily points for 14 days"
if ! az backup policy show -g "$RG" --vault-name "$VAULT" -n "$POLICY" -o none 2>/dev/null; then
  az backup policy show -g "$RG" --vault-name "$VAULT" -n DefaultPolicy -o json \
    | jq --arg n "$POLICY" '.name = $n | .properties.retentionPolicy.dailySchedule.retentionDuration.count = 14' \
    > "$HERE/policy.json"
  az backup policy create -g "$RG" --vault-name "$VAULT" -n "$POLICY" \
    --backup-management-type AzureIaasVM --policy "@$HERE/policy.json" -o none
fi

say "4. Enable backup with the custom policy"
backup_enable_once "$RG" "$VAULT" "$VM" "$POLICY"

say "5. Back up now (do not wait for tonight's schedule)"
RETAIN="$(date -u -d '+7 days' '+%d-%m-%Y' 2>/dev/null || date -u -v+7d '+%d-%m-%Y')"
az backup protection backup-now --resource-group "$RG" --vault-name "$VAULT" \
  --container-name "$VM" --item-name "$VM" --backup-management-type AzureIaasVM \
  --retain-until "$RETAIN" -o none

echo
echo "Backup job started. The first backup takes 20 to 60 minutes."
echo "Watch it:  az backup job list -g $RG --vault-name $VAULT -o table"
echo "When it shows Completed, run ./restore.sh, then ./verify.sh"
