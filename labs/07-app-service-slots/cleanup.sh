#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab07 --yes --no-wait
echo "Cleanup started for rg-az104-lab07. The S1 plan bills by the hour until it is gone."
