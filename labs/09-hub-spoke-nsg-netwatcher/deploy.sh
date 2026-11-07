#!/usr/bin/env bash
# Lab 09: Hub-spoke peering, an NSG on the spoke subnet, and proof with Network Watcher.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab09"
require_login

say "1. Two VNets with NON-overlapping address spaces (peering requires this)"
az group create --name "$RG" --location "$LOC" --tags lab=09 -o none
az network vnet create --resource-group "$RG" --name vnet-hub --address-prefixes 10.10.0.0/16 \
  --subnet-name snet-shared --subnet-prefixes 10.10.1.0/24 -o none
az network vnet create --resource-group "$RG" --name vnet-spoke1 --address-prefixes 10.20.0.0/16 \
  --subnet-name snet-app --subnet-prefixes 10.20.1.0/24 -o none

say "2. Peering is two links, one from each side"
az network vnet peering create --resource-group "$RG" --name hub-to-spoke1 \
  --vnet-name vnet-hub --remote-vnet vnet-spoke1 --allow-vnet-access --allow-forwarded-traffic -o none
az network vnet peering create --resource-group "$RG" --name spoke1-to-hub \
  --vnet-name vnet-spoke1 --remote-vnet vnet-hub --allow-vnet-access --allow-forwarded-traffic -o none

say "3. NSG on the spoke subnet: allow SSH only from the hub, deny the rest of the VNet traffic on 22"
az network nsg create --resource-group "$RG" --name nsg-snet-app -o none
az network nsg rule create --resource-group "$RG" --nsg-name nsg-snet-app --name allow-ssh-from-hub \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 10.10.0.0/16 --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 22 -o none
az network nsg rule create --resource-group "$RG" --nsg-name nsg-snet-app --name deny-ssh-other \
  --priority 200 --direction Inbound --access Deny --protocol Tcp \
  --source-address-prefixes VirtualNetwork --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 22 -o none
az network vnet subnet update --resource-group "$RG" --vnet-name vnet-spoke1 --name snet-app \
  --network-security-group nsg-snet-app -o none

say "4. One small VM in each VNet, no public IPs"
for pair in "vm-hub01:vnet-hub:snet-shared" "vm-app01:vnet-spoke1:snet-app"; do
  IFS=: read -r VM VNET SUBNET <<< "$pair"
  if ! az vm show -g "$RG" -n "$VM" -o none 2>/dev/null; then
    az vm create --resource-group "$RG" --name "$VM" --image Ubuntu2204 --size "$VM_SIZE" \
      --vnet-name "$VNET" --subnet "$SUBNET" --public-ip-address "" --nsg "" \
      --admin-username azureuser --generate-ssh-keys \
      --os-disk-delete-option Delete --nic-delete-option Delete -o none
  fi
done

say "5. Make sure Network Watcher is enabled in this region"
# Usually already on (Azure enables it automatically when you create a VNet).
# Azure may already have created NetworkWatcherRG in another region. Only create it if it is missing.
if [[ "$(az group exists --name NetworkWatcherRG)" != "true" ]]; then
  az group create --name NetworkWatcherRG --location "$LOC" -o none
fi
az network watcher configure --resource-group NetworkWatcherRG --locations "$LOC" --enabled true -o none

echo "Done. Next: ./verify.sh (it runs IP flow verify and next hop)"
