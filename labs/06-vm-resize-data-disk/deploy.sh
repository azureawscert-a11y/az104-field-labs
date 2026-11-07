#!/usr/bin/env bash
# Lab 06: The app is slow and out of space. Resize the VM and add a data disk.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab06"
VM="vm-app01"
require_login

say "1. Starting point: a small VM with no public IP"
az group create --name "$RG" --location "$LOC" --tags lab=06 -o none
if ! az vm show --resource-group "$RG" --name "$VM" -o none 2>/dev/null; then
  az vm create --resource-group "$RG" --name "$VM" --image Ubuntu2204 --size Standard_B2ats_v2 \
    --admin-username azureuser --generate-ssh-keys --public-ip-address "" \
    --os-disk-delete-option Delete --nic-delete-option Delete -o none
fi

say "2. Which sizes can this VM move to without changing hardware cluster?"
az vm list-vm-resize-options --resource-group "$RG" --name "$VM" \
  --query "[?starts_with(name,'Standard_B')].{size:name, vCPUs:numberOfCores, memMB:memoryInMB}" -o table

say "3. Resize B2ats_v2 -> B2als_v2 (the VM restarts, plan a maintenance window)"
az vm resize --resource-group "$RG" --name "$VM" --size Standard_B2als_v2 -o none

say "4. Attach a new 8 GiB Standard SSD data disk at LUN 0"
if [[ "$(az vm show --resource-group "$RG" --name "$VM" --query 'length(storageProfile.dataDisks)' -o tsv)" == "0" ]]; then
  az vm disk attach --resource-group "$RG" --vm-name "$VM" --name "${VM}-data01" \
    --new --size-gb 8 --sku StandardSSD_LRS --lun 0 -o none
fi

say "5. Partition, format and mount the disk inside Linux (run-command, no SSH)"
# shellcheck disable=SC2016  # the script runs inside the VM, so $ must not expand here
az vm run-command invoke --resource-group "$RG" --name "$VM" --command-id RunShellScript --scripts '
# The data disk at LUN 0 always appears at this stable path, whatever the disk sizes.
DISK=$(readlink -f /dev/disk/azure/scsi1/lun0)
if ! lsblk -no MOUNTPOINT "${DISK}1" 2>/dev/null | grep -q /data; then
  parted "$DISK" --script mklabel gpt mkpart primary ext4 0% 100%
  sleep 2; mkfs.ext4 -q "${DISK}1"; mkdir -p /data
  echo "UUID=$(blkid -s UUID -o value ${DISK}1) /data ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
fi
df -h /data' --query "value[0].message" -o tsv

echo "Done. Next: ./verify.sh"
