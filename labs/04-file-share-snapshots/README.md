# Lab 04: Restore a deleted file from a share snapshot

**Ticket INC-1004 · Priority 2 · 25 minutes · < $0.05**

> "I deleted the travel policy from the shared drive by mistake. Can you get it back? HR needs it today." (Office manager)

## Goal
- Azure file share `team-docs` (5 GiB quota) with **soft delete** for shares (7 days).
- A **share snapshot** taken before a risky change.
- Restore a deleted file from the snapshot.

## Steps
1. `./deploy.sh` builds the share, uploads the file, takes a snapshot, then deletes the file (the "accident").
2. Restore it yourself using the hint the script prints. Stuck? `./restore.sh` is the solution.
3. `./verify.sh`

## Know the difference
| Feature | Protects against | Granularity |
|---|---|---|
| Share snapshot | Deleted or changed files | Point-in-time, read-only copy of the whole share |
| Soft delete (shares) | Someone deleting the whole share | Whole share, for the retention days |
| Azure Backup for Files | Both, on a schedule, with retention | Managed snapshots + policy |

## Explain it (interview)
"Soft delete for Azure Files works at the share level. It would not have brought back a single deleted file. The snapshot did. In production I would protect the share with Azure Backup so snapshots are taken on a schedule."

## Cleanup
`./cleanup.sh`
