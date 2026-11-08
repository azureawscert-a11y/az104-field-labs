#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab06"
VM="vm-app01"
require_login
say "Checking lab 06"
expect "VM size is now $VM_SIZE_BIG" \
  "$(az vm show --resource-group "$RG" --name "$VM" --query hardwareProfile.vmSize -o tsv)" "$VM_SIZE_BIG"
expect "VM provisioning succeeded (the resize really happened)" \
  "$(az vm show --resource-group "$RG" --name "$VM" --query provisioningState -o tsv)" "Succeeded"
expect "one data disk attached" \
  "$(az vm show --resource-group "$RG" --name "$VM" --query 'length(storageProfile.dataDisks)' -o tsv)" "1"
expect "data disk is 8 GiB" \
  "$(az disk show --resource-group "$RG" --name "${VM}-data01" --query diskSizeGB -o tsv)" "8"
MNT="$(az vm run-command invoke --resource-group "$RG" --name "$VM" --command-id RunShellScript \
  --scripts "findmnt -no TARGET /data" --query "value[0].message" -o tsv 2>/dev/null)"
if [[ "$MNT" == *"/data"* ]]; then pass "disk is mounted at /data inside the VM"; else fail "/data is not mounted"; fi
summary
