# Capstone: a mini landing zone for a small clinic

**Project PRJ-5000 · 2 to 3 hours · about $0.15 per hour while running**

> "Northwind Clinic (fictional) is moving to Azure. Build a secure starting environment: tagged and governed, a hub and an app network, private storage for patient documents, one app server with backup and an alert. Then hand it over with a diagram and a runbook." (IT director)

## What gets built
| Area | Resources | How |
|---|---|---|
| Governance | Tagged RG, policy **Inherit a tag from the resource group if missing** (CostCenter, Modify effect with a managed identity), policy **Allowed locations** (Canada), Entra group with **Virtual Machine Contributor**, **CanNotDelete** lock | CLI |
| Network | `vnet-hub` 10.10.0.0/16 (snet-shared, snet-pe), `vnet-spoke-app` 10.20.0.0/16 (snet-app + NSG), two-way peering | Bicep |
| Storage | ZRS account, public access disabled, versioning + soft delete, private endpoint in the hub, private DNS zone linked to both VNets | Bicep |
| Compute | `vm-app01` (B2ats_v2, Ubuntu 24.04, no public IP) in the spoke | Bicep |
| Operations | Log Analytics, blob diagnostic logs, action group (email), CPU > 80% alert, Recovery Services vault + DefaultPolicy | Bicep + CLI |

## Steps
1. `EMAIL=you@example.com ./deploy.sh`
2. `./verify.sh`
3. **Hand-over package** (this is what makes it a portfolio project):
   - A diagram of the hub, spoke, peering, private endpoint and DNS (draw.io or Excalidraw).
   - A one-page runbook: how to grant access, restore the VM, respond to the CPU alert.
   - Screenshots of `verify.sh` all PASS. Remove subscription IDs and emails first.
4. `./cleanup.sh`

## Stretch goals
- Add a second spoke and prove spoke-to-spoke traffic does **not** flow (peering is not transitive).
- Add Azure Bastion (Basic SKU) in the hub and connect to `vm-app01` with no public IP. Delete it right after: Bastion bills hourly.
- Add a budget for the resource group with an alert at 80%.
