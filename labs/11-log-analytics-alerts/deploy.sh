#!/usr/bin/env bash
# Lab 11: Storage logs to Log Analytics, KQL, a metric alert to email, and a weekend quiet rule.
# Usage: EMAIL=you@example.com ./deploy.sh
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab11"
LAW="law-lab11"
EMAIL="${EMAIL:-}"
require_login
SA="stlab11$(suffix)"
[[ -n "$EMAIL" ]] || { echo "Set your email first: EMAIL=you@example.com ./deploy.sh"; exit 1; }

# These commands come from CLI extensions. Install them up front so nothing stops to ask.
az extension add --name log-analytics --upgrade -o none
az extension add --name alertsmanagement --upgrade -o none

say "1. Log Analytics workspace (30-day retention) and a storage account to watch"
az group create --name "$RG" --location "$LOC" --tags lab=11 -o none
az monitor log-analytics workspace create --resource-group "$RG" --workspace-name "$LAW" \
  --location "$LOC" --retention-time 30 -o none
LAW_ID="$(az monitor log-analytics workspace show -g "$RG" --workspace-name "$LAW" --query id -o tsv)"
az storage account create --name "$SA" --resource-group "$RG" --location "$LOC" --sku Standard_LRS -o none
SA_ID="$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)"

say "2. Diagnostic setting: blob read/write/delete logs + transaction metrics to the workspace"
az monitor diagnostic-settings create --name diag-blob-to-law \
  --resource "${SA_ID}/blobServices/default" --workspace "$LAW_ID" \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]' \
  --metrics '[{"category":"Transaction","enabled":true}]' -o none

say "3. Action group: who gets told"
az monitor action-group create --resource-group "$RG" --name ag-cloud-ops --short-name cloudops \
  --action email ops-email "$EMAIL" -o none
AG_ID="$(az monitor action-group show -g "$RG" -n ag-cloud-ops --query id -o tsv)"

say "4. Metric alert: more than 50 transactions in 5 minutes (low on purpose so you can trigger it)"
az monitor metrics alert create --resource-group "$RG" --name alert-storage-busy \
  --scopes "$SA_ID" --condition "total Transactions > 50" \
  --window-size 5m --evaluation-frequency 1m --severity 3 \
  --description "Storage account unusually busy (lab 11)" --action "$AG_ID" -o none

say "5. Alert processing rule: no notifications on weekends (alerts still fire and are recorded)"
RG_ID="$(az group show -n "$RG" --query id -o tsv)"
az monitor alert-processing-rule create --resource-group "$RG" --name apr-quiet-weekends \
  --rule-type RemoveAllActionGroups --scopes "$RG_ID" \
  --schedule-recurrence-type Weekly --schedule-recurrence Saturday Sunday \
  --schedule-time-zone "Eastern Standard Time" \
  --description "Suppress notifications on weekends (lab 11)" -o none

say "6. Generate traffic so there is something to see"
KEY="$(az storage account keys list -n "$SA" -g "$RG" --query '[0].value' -o tsv)"
az storage container create --name logs-demo --account-name "$SA" --account-key "$KEY" -o none
echo "hello" > /tmp/lab11.txt
for i in $(seq 1 80); do
  az storage blob upload --container-name logs-demo --name "file$i.txt" --file /tmp/lab11.txt \
    --account-name "$SA" --account-key "$KEY" --overwrite -o none
done
echo "80 uploads done, enough to cross the alert threshold of 50."
echo "Note: on a Saturday or Sunday the processing rule silences the email. The alert still fires; see it in Monitor > Alerts."
echo "Wait 10 to 15 minutes for logs, then run the queries in queries.kql and ./verify.sh"
