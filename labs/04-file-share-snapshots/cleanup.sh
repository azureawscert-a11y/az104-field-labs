#!/usr/bin/env bash
set -uo pipefail
rm -rf "$(dirname "$0")/restored" "$(dirname "$0")/snapshot.txt" /tmp/travel-policy.txt
az group delete --name rg-az104-lab04 --yes --no-wait
echo "Cleanup started for rg-az104-lab04."
