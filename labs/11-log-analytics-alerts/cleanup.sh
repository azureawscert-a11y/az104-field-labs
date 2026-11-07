#!/usr/bin/env bash
set -uo pipefail
rm -f /tmp/lab11.txt
az group delete --name rg-az104-lab11 --yes --no-wait
echo "Cleanup started for rg-az104-lab11 (workspace, storage, alert, action group)."
