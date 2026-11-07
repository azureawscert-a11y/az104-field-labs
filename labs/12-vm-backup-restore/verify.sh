#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab12"
VAULT="rsv-lab12"
VM="vm-files01"
require_login
say "Checking lab 12"
expect "VM is protected by the vault" \
  "$(az backup item list -g "$RG" --vault-name "$VAULT" --query "[?properties.friendlyName=='$VM'] | length(@)" -o tsv)" "1"
expect "custom policy keeps daily points 14 days" \
  "$(az backup policy show -g "$RG" --vault-name "$VAULT" -n pol-daily-14d --query "properties.retentionPolicy.dailySchedule.retentionDuration.count" -o tsv)" "14"
expect "protection policy is pol-daily-14d" \
  "$(az backup item list -g "$RG" --vault-name "$VAULT" --query "[0].properties.policyName" -o tsv)" "pol-daily-14d"
STATUS="$(az backup job list -g "$RG" --vault-name "$VAULT" --query "[?properties.operation=='Backup'] | [0].properties.status" -o tsv)"
if [[ "$STATUS" == "Completed" ]]; then pass "latest backup job Completed"; else fail "latest backup job is '$STATUS' (wait and run again)"; fi
RPS="$(az backup recoverypoint list -g "$RG" --vault-name "$VAULT" --container-name "$VM" --item-name "$VM" \
  --backup-management-type AzureIaasVM --query "length(@)" -o tsv 2>/dev/null)"
if [[ "${RPS:-0}" -ge 1 ]]; then pass "$RPS recovery point(s) available"; else fail "no recovery point yet"; fi
RSTATUS="$(az backup job list -g "$RG" --vault-name "$VAULT" --operation Restore --query "[0].properties.status" -o tsv 2>/dev/null)"
if [[ "$RSTATUS" == "Completed" ]]; then pass "restore job Completed (restored disks are in $RG)"; else fail "restore job is '${RSTATUS:-not started}' (run ./restore.sh, wait, run again)"; fi
summary
