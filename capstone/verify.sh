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
  "$(az role assignment list --scope "$RG_ID" --query "[?roleDefinitionName=='Virtual Machine Contributor' && principalType=='Group'] | length(@)" -o tsv)" "1"
expect "delete lock on the RG" "$(az lock list -g "$RG" --query "length(@)" -o tsv)" "1"
OSDISK="$(az vm show -g "$RG" -n vm-app01 --query storageProfile.osDisk.name -o tsv)"
expect "OS disk inherited CostCenter=IT-100 from the RG (Modify policy)" \
  "$(az disk show -g "$RG" -n "$OSDISK" --query tags.CostCenter -o tsv)" "IT-100"
# Try a region outside the approved list. Some regions refuse new customers on their own
# ("RequestDisallowedByAzure"), which proves nothing about our policy, so skip those and try the next.
DENY_DONE=""
for OTHER in eastus2 canadacentral westus2 centralus northeurope uksouth australiaeast eastus; do
  [[ "$OTHER" == "$LOC" ]] && continue
  if OUT="$(az network nsg create -g "$RG" -n nsg-should-fail --location "$OTHER" --tags CostCenter=IT-100 -o none 2>&1)"; then
    fail "a resource outside the approved region ($OTHER) is denied by policy (it was allowed)"; DENY_DONE=1; break
  elif grep -q RequestDisallowedByPolicy <<< "$OUT"; then
    pass "a resource outside the approved region ($OTHER) is denied by policy"; DENY_DONE=1; break
  elif grep -q RequestDisallowedByAzure <<< "$OUT"; then
    continue
  else
    fail "region policy test failed for another reason: $(grep -m1 -E 'ERROR|Message' <<< "$OUT" | cut -c1-150)"; DENY_DONE=1; break
  fi
done
[[ -n "$DENY_DONE" ]] || fail "could not test the region policy: every test region refused new customers"

say "Network"
expect "hub-spoke peering Connected" \
  "$(az network vnet peering show -g "$RG" --vnet-name vnet-hub -n hub-to-spoke-app --query peeringState -o tsv)" "Connected"
expect "spoke-hub peering Connected" \
  "$(az network vnet peering list -g "$RG" --vnet-name vnet-spoke-app --query "[0].peeringState" -o tsv)" "Connected"
expect "app subnet has the NSG" \
  "$(az network vnet subnet show -g "$RG" --vnet-name vnet-spoke-app -n snet-app --query 'networkSecurityGroup.id' -o tsv | awk -F/ '{print $NF}')" "nsg-snet-app"

say "Storage"
expect "public network access Disabled" "$(az storage account show -n "$SA" -g "$RG" --query publicNetworkAccess -o tsv)" "Disabled"
IP="$(az vm run-command invoke -g "$RG" -n vm-app01 --command-id RunShellScript \
  --scripts "getent hosts ${SA}.blob.core.windows.net | awk '{print \$1}'" --query "value[0].message" -o tsv)"
PEIP="$(pe_ip "$RG" "pe-${SA}-blob")"
IP="$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< "$IP" | head -1)"
if [[ -n "$PEIP" && "$IP" == "$PEIP" ]]; then pass "app VM resolves storage to the private endpoint $IP (DNS zone is linked to the spoke VNet too)"
else fail "expected ${PEIP:-the endpoint IP}, got ${IP:-no answer}"; fi

say "Operations"
# IRPending = protection is on and the first scheduled backup has not run yet (normal right after deploy)
BSTATE="$(backup_state "$RG" rsv-nwclinic vm-app01)"
if [[ "$BSTATE" =~ ^(Protected|IRPending)$ ]]; then pass "vm-app01 is protected by backup ($BSTATE)"; else fail "vm-app01 backup state is '${BSTATE:-not protected}'"; fi
expect "CPU alert enabled" "$(az monitor metrics alert show -g "$RG" -n alert-vm-app01-cpu --query enabled -o tsv)" "true"
summary
