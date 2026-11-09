# az104-field-labs

Hands-on workplace labs for the book **AZ-104: The Azure Administrator Field Guide** (Exam to Work series) by Jey Singh.

Each lab is a realistic help-desk or project ticket that a junior Azure administrator gets in the first months on the job. You deploy it with a script, prove it works with an automatic check, explain it, and delete it.

> Independent learning material. Not affiliated with, authorized, sponsored or approved by Microsoft Corporation. Microsoft, Azure and Microsoft Entra are trademarks of the Microsoft group of companies.

## Free sample of the book

[**Download the free sample (PDF, 22 pages)**](https://github.com/azureawscert-a11y/az104-field-labs/raw/main/sample/AZ-104-Field-Guide-FREE-SAMPLE.pdf): the contents, the "choose your route" page, Chapter 2 (Azure CLI and PowerShell grammar) and Lab 01 as it appears in the book.

The full book has 266 pages: all five exam domains, 12 labs and a capstone, 156 practice questions, a job chapter, and a field reference with portal paths and 28 real error messages. It comes with a Practice Pack of 151 more questions. The link to buy it will be added here at launch.

## What you need

1. **An Azure subscription you are allowed to break.** A free account or Pay-As-You-Go subscription works. Do not use your employer's production subscription.
2. **A budget alert before you start.** Portal: Cost Management > Budgets > Add. Set US$20 a month (or the same in your currency) with email alerts at 50%, 80% and 100%.
3. **A shell with the Azure CLI.** Easiest: Azure Cloud Shell (bash) in the portal, which is already signed in. Locally: install the Azure CLI, then run `az login`.
4. **Owner** (or User Access Administrator + Contributor) on the subscription for labs 01, 02 and the capstone (they create role and policy assignments). Labs 01 also needs permission to create users in Microsoft Entra ID (you have it as the creator of a free account).

## How every lab works

**1. Get the files** (pick one route):

```bash
# Route A, ZIP: in Cloud Shell choose Manage files > Upload > az104-field-labs.zip, then:
unzip az104-field-labs.zip -d az104-field-labs && cd az104-field-labs
chmod +x labs/*/*.sh capstone/*.sh tools/*.sh
```

```bash
# Route B, Git:
git clone https://github.com/azureawscert-a11y/az104-field-labs.git && cd az104-field-labs
chmod +x labs/*/*.sh capstone/*.sh tools/*.sh
git config core.fileMode false   # so chmod does not block "git pull" later
```

**2. Once per subscription, before the first lab** (details in [the setup scripts](#before-the-first-lab-two-setup-scripts) below):

```bash
EMAIL=you@example.com bash tools/setup-subscription.sh   # replace the email first
bash tools/check-region.sh
```

**3. Every lab, from the repo folder:**

```bash
cd labs/03-storage-sas-lifecycle
cat README.md        # read the ticket first
./deploy.sh          # build it
./verify.sh          # PASS / FAIL checks: stop here and explain the result
./cleanup.sh         # delete everything the lab created
```

Then try it yourself: read `deploy.sh`, delete the lab, and rebuild it by typing the commands by hand. That is where the learning happens.

## Safety rules

- Every lab creates **one resource group** named `rg-az104-labNN`. `cleanup.sh` deletes that group and everything billable in it. Azure itself may leave two helper groups behind: `AzureBackupRG_<region>_1` (labs 12 and capstone, created by Azure Backup for VM snapshots; cleanup deletes the lab's snapshots, which are billed) and `NetworkWatcherRG` (labs 09 and capstone, free). Delete them when you finish all labs with `az group delete -n AzureBackupRG_<region>_1 --yes` and `az group delete -n NetworkWatcherRG --yes` (Network Watcher is recreated automatically when needed).
- Run `cleanup.sh` the same day. Several labs create VMs, App Service plans or backup vaults that cost money every hour.
- Never paste real passwords, keys or SAS tokens into GitHub. The scripts print secrets only to your terminal.
- `deploy.sh` stops on the first error. Read the message, fix the cause, and run it again: deploy scripts are safe to re-run. `verify.sh` and `cleanup.sh` keep going and report every problem they find.

## Labs

| # | Ticket | Outline area | Rough cost if deleted same day |
|---|--------|--------------|------|
| 01 | Onboard a new hire: user, group, Reader at resource group scope | Identity, RBAC | Free |
| 02 | Enforce a CostCenter tag with Azure Policy and protect the group with a lock | Governance | Free |
| 03 | Share files with a partner using a revocable SAS + lifecycle rules | Storage access | < $0.05 |
| 04 | Team file share with snapshots and soft delete, restore a deleted file | Azure Files | < $0.05 |
| 05 | Deploy a VM from Bicep, modify the template, preview with what-if | ARM/Bicep, VMs | $0.01 to $0.10 per hour (size) |
| 06 | Resize a VM and add a data disk | VM sizes, disks | $0.02 to $0.15 per hour |
| 07 | Zero-downtime release with an App Service deployment slot swap | App Service | about $0.10 per hour (S1) |
| 08 | Run an image from Azure Container Registry on ACI and Container Apps | Containers | < $0.20 |
| 09 | Hub-spoke peering, NSG, and prove traffic with Network Watcher | Networking | $0.02 to $0.20 per hour (2 VMs) |
| 10 | Lock a storage account to a private endpoint with private DNS | Secure access | $0.03 to $0.12 per hour |
| 11 | Send logs to Log Analytics, query with KQL, alert to email | Monitoring | < $0.05 |
| 12 | Back up a VM with a custom policy and restore its disks | Backup | $0.02 to $0.15 per hour |
| Capstone | Mini landing zone for a small company | All domains | ~ $0.15 per hour |

## Before the first lab: two setup scripts

```bash
EMAIL=you@example.com bash tools/setup-subscription.sh   # providers + US$20 budget alert
bash tools/check-region.sh                               # finds a region and VM size YOUR subscription can use
```

New subscriptions are often blocked from small VM sizes in busy regions (`SkuNotAvailable`) or start with 0 quota for some VM families (`QuotaExceeded`), and some have no App Service Standard quota in a region. In our own test on a brand-new Pay-As-You-Go subscription, Canada Central allowed none of the lab VM sizes, while Canada East, East US and West US 2 allowed `Standard_D2als_v6`. An S1 App Service plan worked in Canada East and West US 2 but not in Canada Central or East US. `check-region.sh` picked Canada East, and all labs passed there.

`check-region.sh` uses `az vm create --validate` (Azure's preflight check, creates nothing) to try the sizes cheapest first: `Standard_B2ats_v2`, `B2s`, `D2als_v6`, `D2as_v5`, `D2as_v4`. It saves the first region that works to `~/.az104labs`, and every lab reads it. Override any value for one run: `LOC=eastus2 ./deploy.sh`.

Costs are rough USD estimates at the time of writing (low end: B2ats_v2, high end: D2-class v6 sizes) and change over time. Check the Azure pricing calculator and your budget alert.

## Lint

`.github/workflows/lint.yml` runs `shellcheck` on every script and `az bicep build` on every Bicep file on each push and pull request.

## License

MIT. See LICENSE.
