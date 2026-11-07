#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab08 --yes --no-wait
echo "Cleanup started for rg-az104-lab08 (registry, ACI, Container Apps environment)."
