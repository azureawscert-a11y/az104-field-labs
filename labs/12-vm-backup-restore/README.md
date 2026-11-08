# Lab 12: Back up a VM and get a file back

**Ticket INC-1012 · Priority 1 · 90 minutes (mostly waiting; the first backup took 56 minutes in our test) · $0.02 to $0.15 per hour**

> "Our billing server has no backup. Turn it on today. And show me you can actually restore something." (Finance director)

## Goal
- **Recovery Services vault** in the same region as the VM.
- A **custom backup policy** `pol-daily-14d` (copy of DefaultPolicy, daily points kept 14 days), applied to the VM.
- An on-demand **backup now**.
- A **restore**: `restore.sh` restores the VM disks from the newest recovery point, and `verify.sh` checks the restore job completed. Optional: File Recovery in the portal for a single file.

## Steps
1. `./deploy.sh` (creates `/home/azureuser/invoices.txt` on the VM, creates the custom policy, then backs it up)
2. Wait for the job: `az backup job list -g rg-az104-lab12 --vault-name rsv-lab12 -o table`
3. `./verify.sh`
4. `./restore.sh` restores the disks (needs a recovery point, so wait for step 2). Watch: `az backup job list -g rg-az104-lab12 --vault-name rsv-lab12 --operation Restore -o table`
5. `./verify.sh` again: the restore check turns PASS when the job is Completed.
6. Optional, single file (portal): vault > Backup items > Azure Virtual Machine > vm-files01 > **File Recovery**. Pick the recovery point, download the script, run it on a machine that can reach Azure. It mounts the backup as a drive so you can copy `invoices.txt` back.
7. `./cleanup.sh`

## Recovery Services vault vs Backup vault
| Recovery Services vault | Backup vault |
|---|---|
| Azure VMs, SQL/SAP HANA in VMs, Azure Files, on-premises (MARS/MABS), **Site Recovery** | Azure Disks, Azure Blobs, Azure Database for PostgreSQL, AKS |

## Explain it (interview)
"Replication is not a backup: GRS copies a deletion to the second region too. A backup is a point-in-time copy with retention. I proved the backup by restoring from it, because a backup you have never restored is only a hope. Soft delete is now always on, so even an attacker with admin rights cannot wipe the backups for 14 days."

## Cleanup
`./cleanup.sh` waits for any running backup job, stops protection and deletes the backup data. Since 2026 every vault is **secure by default**: soft delete is always on and cannot be turned off, so Azure keeps the deleted backup for 14 days (free). Cleanup then force-deletes the vault; Azure moves it into the same 14-day soft-deleted state and the resource group is removed the same day (tested November 2026). If Azure ever refuses the vault delete, cleanup removes everything else and tells you the date to run it again. If the first backup is still running, cleanup can take up to an hour.
