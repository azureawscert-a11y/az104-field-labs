#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../common/lib.sh
source "$(dirname "$0")/../common/lib.sh"

RG="rg-az104-capstone"
require_login
RG_ID="$(az group show -n "$RG" --query id -o tsv)"
SA="$(az deployment group show -g "$RG" -n capstone --query properties.outputs.storageAccountName.value -o tsv)"

say "Governance"
expect "2 policy assignments on the RG" \
  "$(az policy assignment list --scope "$RG_ID" --query "[?starts_with(name,'cap-')] | length(@)" -o tsv)" "2"
expect "ops group has VM Contributor" \
  "$(az role assignment list --scope "$RG_ID" --query "[?roleDefinitionName=='Virtual Machine Contributor'] | length(@)" -o tsv)" "1"
expect "delete lock on the RG" "$(az lock list -g "$RG" --query "length(@)" -o tsv)" "1"
OSDISK="$(az vm show -g "$RG" -n vm-app01 --query storageProfile.osDisk.name -o tsv)"
expect "OS disk inherited CostCenter=IT-100 from the RG (Modify policy)" \
  "$(az disk show -g "$RG" -n "$OSDISK" --query tags.CostCenter -o tsv)" "IT-100"
OTHER="westeurope"; [[ "$LOC" == "westeurope" ]] && OTHER="eastus"
expect_fail "a resource outside the approved region ($OTHER) is denied" \
  az network nsg create -g "$RG" -n nsg-should-fail --location "$OTHER" --tags CostCenter=IT-100

say "Network"
expect "hub-spoke peering Connected" \
  "$(az network vnet peering show -g "$RG" --vnet-name vnet-hub -n hub-to-spoke-app --query peeringState -o tsv)" "Connected"
expect "app subnet has the NSG" \
  "$(az network vnet subnet show -g "$RG" --vnet-name vnet-spoke-app -n snet-app --query 'networkSecurityGroup.id' -o tsv | awk -F/ '{print $NF}')" "nsg-snet-app"

say "Storage"
expect "public network access Disabled" "$(az storage account show -n "$SA" -g "$RG" --query publicNetworkAccess -o tsv)" "Disabled"
IP="$(az vm run-command invoke -g "$RG" -n vm-app01 --command-id RunShellScript \
  --scripts "getent hosts ${SA}.blob.core.windows.net | awk '{print \$1}'" --query "value[0].message" -o tsv)"
if [[ "$IP" == *"10.10.2."* ]]; then pass "app VM resolves storage to the private endpoint (spoke uses hub DNS zone link)"; else fail "expected 10.10.2.x, got $IP"; fi

say "Operations"
expect "VM is protected by backup" \
  "$(az backup item list -g "$RG" --vault-name rsv-nwclinic --query "length(@)" -o tsv)" "1"
expect "CPU alert enabled" "$(az monitor metrics alert show -g "$RG" -n alert-vm-app01-cpu --query enabled -o tsv)" "true"
summary
