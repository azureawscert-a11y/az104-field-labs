#!/usr/bin/env bash
# Lab 04: Team file share with soft delete and a snapshot taken before a risky change.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab04"
SHARE="team-docs"
require_login
SA="stlab04$(suffix)"

say "1. Storage account and a 5 GiB file share"
az group create --name "$RG" --location "$LOC" --tags lab=04 -o none
az storage account create --name "$SA" --resource-group "$RG" --location "$LOC" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 -o none
az storage share-rm create --storage-account "$SA" --resource-group "$RG" --name "$SHARE" --quota 5 -o none
KEY="$(az storage account keys list --account-name "$SA" --resource-group "$RG" --query '[0].value' -o tsv)"

say "2. Soft delete for file shares: 7 days"
az storage account file-service-properties update --account-name "$SA" --resource-group "$RG" \
  --enable-delete-retention true --delete-retention-days 7 -o none

say "3. Upload the team's policy document"
echo "Travel policy v1: economy class for flights under 6 hours." > /tmp/travel-policy.txt
az storage file upload --share-name "$SHARE" --source /tmp/travel-policy.txt \
  --path travel-policy.txt --account-name "$SA" --account-key "$KEY" -o none
rm -f /tmp/travel-policy.txt   # so the only way back is the snapshot

say "4. Take a snapshot BEFORE the risky change"
SNAP="$(az storage share snapshot --name "$SHARE" --account-name "$SA" --account-key "$KEY" --query snapshot -o tsv)"
echo "$SNAP" > "$(dirname "$0")/snapshot.txt"
echo "  Snapshot taken: $SNAP (saved to snapshot.txt)"

say "5. The 'accident': someone deletes the file"
az storage file delete --share-name "$SHARE" --path travel-policy.txt \
  --account-name "$SA" --account-key "$KEY" -o none
echo "File deleted from the live share. Your job: restore it from the snapshot."
echo
echo "Hint:"
echo "  SNAP=\$(cat snapshot.txt)"
echo "  KEY=\$(az storage account keys list --account-name $SA -g $RG --query '[0].value' -o tsv)"
echo "  az storage file download --share-name $SHARE --path travel-policy.txt --snapshot \"\$SNAP\" --dest ./travel-policy.txt --account-name $SA --account-key \"\$KEY\""
echo "  then upload it back with az storage file upload, and run ./verify.sh"
