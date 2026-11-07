#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
rm -f "$HERE/sas.txt" /tmp/q3-report.txt
az group delete --name rg-az104-lab03 --yes --no-wait
echo "Cleanup started for rg-az104-lab03."
