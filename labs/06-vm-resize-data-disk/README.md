# Lab 06: Resize a VM and add a data disk

**Ticket INC-1006 · Priority 2 · 30 minutes · $0.02 to $0.15 per hour**

> "The reporting server keeps freezing and the disk is almost full. Can you give it more power and more space tonight?" (App owner)

## Goal
- Resize `vm-app01` from **Standard_B2ats_v2** to **Standard_B2als_v2** (or the pair `tools/check-region.sh` chose for your subscription).
- Attach a new 8 GiB **Standard SSD** data disk at LUN 0.
- Partition, format and mount it at `/data` with run-command.

## Steps
1. `./deploy.sh`
2. `./verify.sh`

## Things to know
- Resizing restarts the VM. If the new size is not in `list-vm-resize-options`, **deallocate** first (`az vm deallocate`), then resize, then start.
- A new data disk is attached raw. Azure does not format it for you.
- Use LUNs to identify disks. Linux device names (`/dev/sdc`) can change between boots, so mount by UUID in `/etc/fstab`.
- You can grow a disk later (`az disk update --size-gb`), never shrink it.

## Explain it (interview)
"I checked available sizes first, scheduled the restart, resized up within the same family, and added a separate data disk so app data is not on the OS disk. Then I mounted it by UUID so it survives reboots."

## Cleanup
`./cleanup.sh`
