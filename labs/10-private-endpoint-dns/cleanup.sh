#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab10 --yes --no-wait
echo "Cleanup started for rg-az104-lab10."
