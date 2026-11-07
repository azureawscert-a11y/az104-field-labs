#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab05 --yes --no-wait
echo "Cleanup started for rg-az104-lab05 (the VM, disk, NIC, NSG and VNet go with it)."
