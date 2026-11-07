# Lab 05: Deploy a VM from Bicep, preview first

**Ticket CHG-2005 · Priority 3 · 30 minutes · about $0.05 per hour**

> "Dev needs a small Linux test server. No public IP. And from now on, every change goes through a template we can review." (Team lead)

## Goal
- Read `main.bicep`: parameters, variables, four resources (NSG, VNet, NIC, VM), outputs.
- Preview with **what-if** before deploying.
- Deploy, then **modify** the deployment: change the tags, then turn on the data disk block (`addDataDisk`) and see what-if report only the change before you deploy v2.
- Modify the Bicep file yourself (exercise below) and redeploy.

## Steps
1. `./deploy.sh` (creates an SSH key in `~/.ssh` if you don't have one)
2. `./verify.sh` confirms the deployment, the VM state, no public IP, and runs a command inside the VM with **run-command** (no SSH needed).
3. **Modify the file yourself:** open `main.bicep`, add a second NSG rule `allow-https-from-vnet` (priority 210, port 443) under `securityRules`, run `az bicep build --file main.bicep` to check it, then
   `az deployment group what-if -g rg-az104-lab05 --template-file main.bicep --parameters adminPublicKey="$(cat ~/.ssh/id_rsa.pub)" addDataDisk=true`
   and confirm what-if shows a `~ Modify` on `nsg-web` only. Deploy it with `az deployment group create` (same parameters).
4. Extra practice:
   - `az bicep decompile --file main.json` after `az bicep build --file main.bicep` to see ARM JSON and back.
   - In the portal, open the resource group > Export template and compare it with `main.bicep`.

## What-if symbols
| Symbol | Meaning |
|---|---|
| `+` Create | resource will be created |
| `~` Modify | an existing property will change |
| `-` Delete | only in Complete mode |
| `=` NoChange / `*` Ignore | nothing happens |

## Explain it (interview)
"I deploy from Bicep so changes are reviewed in a pull request and repeatable. What-if shows the exact impact before I touch production. Incremental mode (the default) never deletes resources that are not in the template."

## Cleanup
`./cleanup.sh`
