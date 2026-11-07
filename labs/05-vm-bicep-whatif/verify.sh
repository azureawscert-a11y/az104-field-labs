#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab05"
require_login
say "Checking lab 05"
expect "deployment lab05-v1 succeeded" \
  "$(az deployment group show --resource-group "$RG" --name lab05-v1 --query properties.provisioningState -o tsv)" "Succeeded"
expect "deployment lab05-v2 (data disk added) succeeded" \
  "$(az deployment group show --resource-group "$RG" --name lab05-v2 --query properties.provisioningState -o tsv)" "Succeeded"
expect "VM has 1 data disk at LUN 0" \
  "$(az vm show --resource-group "$RG" --name vm-web01 --query "storageProfile.dataDisks[?lun==\`0\`] | length(@)" -o tsv)" "1"
expect "VM is running" \
  "$(az vm show --resource-group "$RG" --name vm-web01 --show-details --query powerState -o tsv)" "VM running"
expect "VM has NO public IP" \
  "$(az vm show --resource-group "$RG" --name vm-web01 --show-details --query publicIps -o tsv)" ""
expect "VM size is $VM_SIZE" \
  "$(az vm show --resource-group "$RG" --name vm-web01 --query hardwareProfile.vmSize -o tsv)" "$VM_SIZE"
OS="$(az vm run-command invoke --resource-group "$RG" --name vm-web01 --command-id RunShellScript \
  --scripts "grep PRETTY_NAME /etc/os-release" --query "value[0].message" -o tsv 2>/dev/null)"
if [[ "$OS" == *Ubuntu* ]]; then pass "run-command reached the guest OS (Ubuntu)"; else fail "run-command did not return Ubuntu"; fi
summary
