#!/usr/bin/env bash
# Lab 10: Storage reachable ONLY from inside the VNet, through a private endpoint with private DNS.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab10"
VNET="vnet-lab10"
ZONE="privatelink.blob.core.windows.net"
require_login
SA="stlab10$(suffix)"

say "1. VNet with a workload subnet and a subnet for private endpoints"
az group create --name "$RG" --location "$LOC" --tags lab=10 -o none
az network vnet create --resource-group "$RG" --name "$VNET" --address-prefixes 10.60.0.0/16 \
  --subnet-name snet-app --subnet-prefixes 10.60.1.0/24 -o none
az network vnet subnet create --resource-group "$RG" --vnet-name "$VNET" --name snet-pe \
  --address-prefixes 10.60.2.0/24 -o none

say "2. Storage account with PUBLIC network access disabled"
az storage account create --name "$SA" --resource-group "$RG" --location "$LOC" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --public-network-access Disabled -o none
SA_ID="$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)"

say "3. Private endpoint for the BLOB sub-resource"
az network private-endpoint create --resource-group "$RG" --name "pe-${SA}-blob" \
  --vnet-name "$VNET" --subnet snet-pe --private-connection-resource-id "$SA_ID" \
  --group-id blob --connection-name "conn-${SA}-blob" -o none

say "4. Private DNS zone, linked to the VNet, with an automatic A record"
az network private-dns zone create --resource-group "$RG" --name "$ZONE" -o none
az network private-dns link vnet create --resource-group "$RG" --zone-name "$ZONE" \
  --name link-lab10 --virtual-network "$VNET" --registration-enabled false -o none
az network private-endpoint dns-zone-group create --resource-group "$RG" \
  --endpoint-name "pe-${SA}-blob" --name default --private-dns-zone "$ZONE" --zone-name blob -o none

say "5. A test VM inside the VNet (no public IP)"
if ! az vm show -g "$RG" -n vm-test01 -o none 2>/dev/null; then
  az vm create --resource-group "$RG" --name vm-test01 --image Ubuntu2204 --size "$VM_SIZE" \
    --vnet-name "$VNET" --subnet snet-app --public-ip-address "" --nsg "" \
    --admin-username azureuser --generate-ssh-keys \
    --os-disk-delete-option Delete --nic-delete-option Delete -o none
fi
echo "Done. Next: ./verify.sh"
