# Capstone: a mini landing zone for a small clinic

**Project PRJ-5000 · 2 to 3 hours · about $0.15 per hour while running**

> "Northwind Clinic (fictional) is moving to Azure. Build a secure starting environment: tagged and governed, a hub and an app network, private storage for patient documents, one app server with backup and an alert. Then hand it over with a diagram and a runbook." (IT director)

## What gets built
| Area | Resources | How |
|---|---|---|
| Governance | Tagged RG, policy **Inherit a tag from the resource group if missing** (CostCenter, Modify effect with a managed identity), policy **Allowed locations** (your lab region only), Entra group with **Virtual Machine Contributor**, **CanNotDelete** lock | CLI |
| Network | `vnet-hub` 10.10.0.0/16 (snet-shared, snet-pe), `vnet-spoke-app` 10.20.0.0/16 (snet-app + NSG), two-way peering | Bicep |
| Storage | ZRS account (LRS in regions without availability zones), public access disabled, versioning + soft delete, private endpoint in the hub, private DNS zone linked to both VNets | Bicep |
| Compute | `vm-app01` (your lab VM size, Ubuntu 24.04, no public IP) in the spoke | Bicep |
| Operations | Log Analytics, blob diagnostic logs, action group (email), CPU > 80% alert, Recovery Services vault + DefaultPolicy | Bicep + CLI |

## Steps
1. `EMAIL=you@example.com ./deploy.sh`
2. `./verify.sh`
3. **Hand-over package** (this is what makes it a portfolio project):
   - A diagram of the hub, spoke, peering, private endpoint and DNS (draw.io or Excalidraw).
   - A one-page runbook: how to grant access, restore the VM, respond to the CPU alert.
   - Screenshots of `verify.sh` all PASS. Remove subscription IDs and emails first.
4. Grade the handover with the checklist below, then `./cleanup.sh`.

## Handover checklist
| Part | Passes when | Proof to include |
|---|---|---|
| 1. Diagram | Shows both VNets with their ranges, the peering, the private endpoint in snet-pe, the private DNS zone linked to both VNets, the VM with no public IP, and where the vault and workspace sit. Someone else can trace the path the VM takes to reach storage. | The diagram, plus one sentence describing that path |
| 2. Evidence | `verify.sh` all PASS, plus one expected failure you caused on purpose (for example a resource outside the allowed region denied by policy), with the error text. | Two screenshots, IDs and emails removed |
| 3. Runbook | Each task (grant access, respond to the CPU alert, restore the VM) has a starting state, the commands, proof it worked, and how to undo it. Another person can follow it without asking you. | The runbook, from the template below |
| 4. One change | Pick a new requirement (a second spoke, a 70% CPU threshold, a different backup policy) and explain in three to five sentences what you would change and what could break. | A "Change request" section in your README |

Runbook template, one block per task:

```markdown
# Runbook: restore vm-app01
Scope:       rg-az104-capstone (your region). Who may run it: Backup Operator or higher
Before:      a recovery point exists (Backup items in rsv-nwclinic shows one)
Steps:       1. the az backup restore command you used
             2. the command that checks the restore job finished
Proof:       what you ran to show it worked, and what it showed
Undo:        how to remove what the restore created
If it fails: the first thing to check (job error, permissions, region)
```

The real test: give one runbook task to someone else and let them do it from your document alone. Where they get stuck, fix the document.

## Stretch goals
- Add a second spoke and prove spoke-to-spoke traffic does **not** flow (peering is not transitive).
- Add Azure Bastion (Basic SKU) in the hub and connect to `vm-app01` with no public IP. Delete it right after: Bastion bills hourly.
- Add a budget for the resource group with an alert at 80%.
