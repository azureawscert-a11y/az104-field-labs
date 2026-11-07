#!/usr/bin/env bash
# Lab 04 solution: restore the deleted file from the share snapshot. Try it by hand first.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab04"
SHARE="team-docs"
require_login
SA="stlab04$(suffix)"
KEY="$(az storage account keys list --account-name "$SA" --resource-group "$RG" --query '[0].value' -o tsv)"

HERE="$(cd "$(dirname "$0")" && pwd)"
SNAP="$(cat "$HERE/snapshot.txt")"
echo "Using snapshot: $SNAP"
mkdir -p "$HERE/restored"
az storage file download --share-name "$SHARE" --path travel-policy.txt --snapshot "$SNAP" \
  --dest "$HERE/restored/travel-policy.txt" --account-name "$SA" --account-key "$KEY" -o none
az storage file upload --share-name "$SHARE" --source "$HERE/restored/travel-policy.txt" \
  --path travel-policy.txt --account-name "$SA" --account-key "$KEY" -o none
echo "Restored travel-policy.txt to the live share. Run ./verify.sh"
