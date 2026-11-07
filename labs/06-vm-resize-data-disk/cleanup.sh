#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab06 --yes --no-wait
echo "Cleanup started for rg-az104-lab06. Data disks are separate resources: deleting the group removes them too."
