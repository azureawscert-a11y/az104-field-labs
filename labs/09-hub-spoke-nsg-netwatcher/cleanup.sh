#!/usr/bin/env bash
set -uo pipefail
az group delete --name rg-az104-lab09 --yes --no-wait
echo "Cleanup started for rg-az104-lab09. NetworkWatcherRG is shared by your subscription: leave it."
