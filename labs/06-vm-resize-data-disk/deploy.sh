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
  az vm create --resource-group "$RG" --name "$VM" --image Ubuntu2204 --size "$VM_SIZE" \
    --admin-username azureuser --generate-ssh-keys --public-ip-address "" \
    --os-disk-delete-option Delete --nic-delete-option Delete -o none
fi

say "2. Which sizes can this VM move to without changing hardware cluster?"
az vm list-vm-resize-options --resource-group "$RG" --name "$VM" \
  --query "[?numberOfCores<=\`2\`].{size:name, vCPUs:numberOfCores, memMB:memoryInMB} | [:12]" -o table

say "3. Resize $VM_SIZE -> $VM_SIZE_BIG (the VM restarts, plan a maintenance window)"
# A failed resize can leave the NEW size in the VM model while the VM still runs the old one,
# so check the provisioning state too, not just the size.
if [[ "$(az vm show -g "$RG" -n "$VM" --query hardwareProfile.vmSize -o tsv)" != "$VM_SIZE_BIG" ||
      "$(az vm show -g "$RG" -n "$VM" --query provisioningState -o tsv)" != "Succeeded" ]]; then
  if [[ "$(az vm list-vm-resize-options -g "$RG" -n "$VM" --query "[?name=='$VM_SIZE_BIG'] | length(@)" -o tsv)" == "1" ]]; then
    az vm resize --resource-group "$RG" --name "$VM" --size "$VM_SIZE_BIG" -o none
  else
    echo "  $VM_SIZE_BIG is not on this hardware cluster: deallocate, resize, start"
    az vm deallocate -g "$RG" -n "$VM" -o none
    az vm resize -g "$RG" -n "$VM" --size "$VM_SIZE_BIG" -o none
    az vm start -g "$RG" -n "$VM" -o none
  fi
fi

say "4. Attach a new 8 GiB Standard SSD data disk at LUN 0"
if [[ "$(az vm show --resource-group "$RG" --name "$VM" --query 'length(storageProfile.dataDisks)' -o tsv)" == "0" ]]; then
  az vm disk attach --resource-group "$RG" --vm-name "$VM" --name "${VM}-data01" \
    --new --size-gb 8 --sku StandardSSD_LRS --lun 0 -o none
fi

say "5. Partition, format and mount the disk inside Linux (run-command, no SSH)"
# A run that stopped halfway can leave the VM deallocated, and run-command needs it running.
POWER="$(az vm get-instance-view -g "$RG" -n "$VM" \
  --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv)"
if [[ "$POWER" != "PowerState/running" ]]; then
  echo "  VM is $POWER: starting it"
  az vm start -g "$RG" -n "$VM" -o none
fi
# Safe to re-run: it only partitions a completely blank disk, only formats a partition with no
# filesystem, and stops if the disk holds anything it does not expect.
# shellcheck disable=SC2016  # the script runs inside the VM, so $ must not expand here
az vm run-command invoke --resource-group "$RG" --name "$VM" --command-id RunShellScript --scripts '
set -e
# Find the data disk at LUN 0. SCSI sizes (B, Dv4...) use /dev/disk/azure/scsi1/lun0;
# newer NVMe sizes (v6) use /dev/disk/azure/data/by-lun/0 or /dev/nvme0n2.
DISK=""
for p in /dev/disk/azure/data/by-lun/0 /dev/disk/azure/scsi1/lun0 /dev/nvme0n2; do
  [ -e "$p" ] && DISK=$(readlink -f "$p") && break
done
[ -n "$DISK" ] || { echo "ERROR: no data disk found at LUN 0"; exit 1; }
PART="${DISK}1"; case "$DISK" in *nvme*) PART="${DISK}p1";; esac
if [ ! -e "$PART" ]; then
  # No partition 1. Only partition a disk that is provably blank, or stop and touch nothing:
  # 1) "blkid -p" exits 2 when it finds no filesystem or partition table. It also exits 2 when it
  #    cannot open the disk, so 2) read the first MiB ourselves: a new Azure disk is all zeros, and
  #    every partition table or filesystem writes something there. A failed read stops the script.
  rc=0; blkid -p "$DISK" >/dev/null || rc=$?
  [ "$rc" -eq 2 ] || { echo "ERROR: $DISK has no partition 1 but is not blank (blkid exit $rc). Not touching it."; exit 1; }
  rm -f /tmp/lab06-head.bin; dd if="$DISK" of=/tmp/lab06-head.bin bs=1M count=1 status=none
  [ "$(wc -c < /tmp/lab06-head.bin)" -eq 1048576 ] || { echo "ERROR: could not read the start of $DISK. Not touching it."; exit 1; }
  [ "$(tr -d "\\000" < /tmp/lab06-head.bin | wc -c)" -eq 0 ] || { echo "ERROR: $DISK is not blank (data in its first MiB). Not touching it."; exit 1; }
  parted "$DISK" --script mklabel gpt mkpart primary ext4 0% 100%
  partprobe "$DISK"; udevadm settle
fi
# A new GPT partition already has a PARTUUID, so test for a FILESYSTEM type, not just "blkid works".
FSTYPE=$(blkid -s TYPE -o value "$PART" || true)
[ -n "$FSTYPE" ] || mkfs.ext4 -q "$PART"
UUID=$(blkid -s UUID -o value "$PART")
[ -n "$UUID" ] || { echo "ERROR: no filesystem UUID on $PART"; exit 1; }
mkdir -p /data
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q /data || mount /data
df -h /data' --query "value[0].message" -o tsv

echo "Done. Next: ./verify.sh"
