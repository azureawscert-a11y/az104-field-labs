#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab11"
require_login
SA="stlab11$(suffix)"
say "Checking lab 11"
SA_ID="$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)"
expect "diagnostic setting sends blob logs to the workspace" \
  "$(az monitor diagnostic-settings list --resource "${SA_ID}/blobServices/default" --query "length([?name=='diag-blob-to-law'])" -o tsv)" "1"
expect "action group has one email receiver" \
  "$(az monitor action-group show -g "$RG" -n ag-cloud-ops --query 'length(emailReceivers)' -o tsv)" "1"
expect "metric alert is enabled" \
  "$(az monitor metrics alert show -g "$RG" -n alert-storage-busy --query enabled -o tsv)" "true"
APR="$(az monitor alert-processing-rule show -g "$RG" -n apr-quiet-weekends \
  --query "[properties.enabled, properties.actions[0].actionType, join(',', properties.schedule.recurrences[0].daysOfWeek)]" -o tsv | tr '\t\n' '  ' | xargs)"
expect "weekend rule is enabled and removes notifications on Saturday and Sunday" "$APR" "true RemoveAllActionGroups Saturday,Sunday"

CUST="$(az monitor log-analytics workspace show -g "$RG" --workspace-name law-lab11 --query customerId -o tsv)"
ROWS="$(az monitor log-analytics query --workspace "$CUST" \
  --analytics-query "StorageBlobLogs | where OperationName == 'PutBlob' | count" \
  --query "[0].Count" -o tsv 2>/dev/null)"
if [[ "${ROWS:-0}" =~ ^[0-9]+$ && "$ROWS" -gt 0 ]]; then pass "KQL finds $ROWS PutBlob operations in the workspace"
else fail "no PutBlob rows yet. Logs can take 15 minutes; run verify.sh again later"; fi
summary
