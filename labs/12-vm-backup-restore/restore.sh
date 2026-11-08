#!/usr/bin/env bash
# Lab 12: restore the VM's disks from the latest recovery point (Restore disks).
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
require_login
SUB="$(az account show --query id -o tsv)"
# Staging account name must be globally unique: derive it from your subscription ID
SA="st12$(echo -n "$SUB" | tr -d '-' | cut -c1-16)"   # no md5sum: it doesn't exist on macOS

say "1. Staging storage account in the same region (restore-disks needs one)"
az storage account create -g "$RG" -n "$SA" -l "$LOC" --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false -o none

say "2. Pick the newest recovery point"
RP="$(az backup recoverypoint list -g "$RG" --vault-name "$VAULT" --container-name "$VM" --item-name "$VM" \
  --backup-management-type AzureIaasVM --query "[0].name" -o tsv)"
[[ -n "$RP" ]] || { echo "No recovery point yet. Wait for the backup job to finish, then run again."; exit 1; }
echo "  recovery point: $RP"

say "3. Restore the disks as managed disks into $RG"
az backup restore restore-disks -g "$RG" --vault-name "$VAULT" \
  --container-name "$VM" --item-name "$VM" --rp-name "$RP" \
  --storage-account "$SA" --target-resource-group "$RG" -o none

echo
echo "Restore job started (10 to 30 minutes). Watch it:"
echo "  az backup job list -g $RG --vault-name $VAULT --operation Restore -o table"
echo "Then run ./verify.sh"
