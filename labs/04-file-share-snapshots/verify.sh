#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab04"
SHARE="team-docs"
require_login
SA="stlab04$(suffix)"
KEY="$(az storage account keys list --account-name "$SA" --resource-group "$RG" --query '[0].value' -o tsv)"

say "Checking lab 04"
expect "share soft delete is on" \
  "$(az storage account file-service-properties show --account-name "$SA" --resource-group "$RG" --query 'shareDeleteRetentionPolicy.enabled' -o tsv)" "true"
SNAPS="$(az storage share list --include-snapshots --account-name "$SA" --account-key "$KEY" --query "[?snapshot!=null] | length(@)" -o tsv)"
if [[ "$SNAPS" -ge 1 ]]; then pass "at least one share snapshot exists ($SNAPS)"; else fail "no share snapshot found"; fi
check "travel-policy.txt is back in the live share" \
  az storage file show --share-name "$SHARE" --path travel-policy.txt --account-name "$SA" --account-key "$KEY"
summary
