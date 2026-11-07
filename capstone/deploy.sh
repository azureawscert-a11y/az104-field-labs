#!/usr/bin/env bash
# Capstone: mini landing zone for "Northwind Clinic" (fictional).
# Usage: EMAIL=you@example.com ./deploy.sh
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lib.sh
source "$(dirname "$0")/../common/lib.sh"

RG="rg-az104-capstone"
HERE="$(cd "$(dirname "$0")" && pwd)"
EMAIL="${EMAIL:-}"
require_login
[[ -n "$EMAIL" ]] || { echo "Set your email first: EMAIL=you@example.com ./deploy.sh"; exit 1; }
KEYFILE="$HOME/.ssh/id_rsa.pub"
[[ -f "$KEYFILE" ]] || ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" -q

say "1. Governance first: tagged resource group + policies BEFORE any resource exists"
az group create --name "$RG" --location "$LOC" --tags CostCenter=IT-100 env=prod owner=cloud-ops -o none
RG_ID="$(az group show -n "$RG" --query id -o tsv)"

# Modify (not Deny): every new resource, including OS disks and NICs that templates often forget to tag,
# automatically inherits CostCenter from the resource group. Modify policies need a managed identity.
TAG_POLICY="$(az policy definition list --query "[?displayName=='Inherit a tag from the resource group if missing'].name | [0]" -o tsv)"
if ! az policy assignment show --name cap-inherit-costcenter --scope "$RG_ID" -o none 2>/dev/null; then
  az policy assignment create --name cap-inherit-costcenter --display-name "Inherit CostCenter tag from RG (capstone)" \
    --policy "$TAG_POLICY" --scope "$RG_ID" --params '{"tagName":{"value":"CostCenter"}}' \
    --mi-system-assigned --location "$LOC" --identity-scope "$RG_ID" --role Contributor -o none
fi

LOC_POLICY="$(az policy definition list --query "[?displayName=='Allowed locations'].name | [0]" -o tsv)"
az policy assignment show --name cap-allowed-locations --scope "$RG_ID" -o none 2>/dev/null || \
az policy assignment create --name cap-allowed-locations --display-name "Approved regions only (capstone)" \
  --policy "$LOC_POLICY" --scope "$RG_ID" \
  --params "{\"listOfAllowedLocations\":{\"value\":[\"$LOC\",\"global\"]}}" -o none

say "2. RBAC: an ops group gets Virtual Machine Contributor on the resource group"
if [[ -z "$(az ad group list --display-name grp-clinic-ops --query '[0].id' -o tsv)" ]]; then
  az ad group create --display-name grp-clinic-ops --mail-nickname grp-clinic-ops -o none
fi
OPS_ID="$(az ad group show --group grp-clinic-ops --query id -o tsv)"
assign_role "$OPS_ID" Group "Virtual Machine Contributor" "$RG_ID"

say "3. Infrastructure from Bicep (preview, then deploy)"
# ZRS spreads copies over availability zones. Regions without zones (for example canadaeast) only offer LRS/GRS.
ZONES="$(az account list-locations --query "[?name=='$LOC'] | [0].availabilityZoneMappings | length(@)" -o tsv 2>/dev/null || true)"
if [[ "${ZONES:-0}" -gt 0 ]]; then SKU=Standard_ZRS; else SKU=Standard_LRS; fi
echo "  storage redundancy for $LOC: $SKU"
az deployment group what-if -g "$RG" --template-file "$HERE/main.bicep" \
  --parameters adminPublicKey="$(cat "$KEYFILE")" alertEmail="$EMAIL" vmSize="$VM_SIZE" storageSku="$SKU" --result-format ResourceIdOnly
az deployment group create --name capstone -g "$RG" --template-file "$HERE/main.bicep" \
  --parameters adminPublicKey="$(cat "$KEYFILE")" alertEmail="$EMAIL" vmSize="$VM_SIZE" storageSku="$SKU" -o none

say "4. Backup the app VM"
az backup vault create -g "$RG" --name rsv-nwclinic --location "$LOC" --tags CostCenter=IT-100 -o none
# Soft delete is always on for new vaults (secure by default). cleanup.sh explains what that means.
backup_enable_once "$RG" rsv-nwclinic vm-app01

say "5. Protect the whole landing zone from accidental deletion"
az lock create --name lock-capstone --lock-type CanNotDelete --resource-group "$RG" \
  --notes "Capstone landing zone. Remove only with change approval." -o none

echo "Done. Run ./verify.sh, then draw the diagram and write the runbook described in README.md"
