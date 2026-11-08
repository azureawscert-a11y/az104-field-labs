#!/usr/bin/env bash
# Lab 03: Share files with a partner through a SAS tied to a stored access policy, plus lifecycle rules.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab03"
CONTAINER="partner-share"
POLICY_NAME="partner-read-30d"
require_login
SA="stlab03$(suffix)"
HERE="$(cd "$(dirname "$0")" && pwd)"

say "1. Resource group and a secure-by-default storage account"
az group create --name "$RG" --location "$LOC" --tags lab=03 -o none
az storage account create --name "$SA" --resource-group "$RG" --location "$LOC" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --https-only true -o none
KEY="$(az storage account keys list --account-name "$SA" --resource-group "$RG" --query '[0].value' -o tsv)"

say "2. Private container and a sample report"
az storage container create --name "$CONTAINER" --account-name "$SA" --account-key "$KEY" -o none
echo "Q3 revenue report (lab)" > /tmp/q3-report.txt
az storage blob upload --container-name "$CONTAINER" --name reports/q3-report.txt \
  --file /tmp/q3-report.txt --account-name "$SA" --account-key "$KEY" --overwrite -o none

say "3. Stored access policy: read + list for 30 days"
EXPIRY="$(date -u -d '+30 days' '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+30d '+%Y-%m-%dT%H:%MZ')"
# Note: "policy show" exits 0 even when the policy is missing, so never use it as a test.
# "policy create" overwrites a policy with the same name, so this is safe to re-run.
az storage container policy create --container-name "$CONTAINER" --name "$POLICY_NAME" \
  --permissions rl --expiry "$EXPIRY" --account-name "$SA" --account-key "$KEY" -o none
az storage container policy list --container-name "$CONTAINER" --account-name "$SA" --account-key "$KEY" -o table

say "4. Service SAS that points at the policy (no permissions or expiry inside the token)"
SAS="$(az storage container generate-sas --name "$CONTAINER" --policy-name "$POLICY_NAME" \
  --https-only --account-name "$SA" --account-key "$KEY" -o tsv)"
URL="$(az storage blob url --container-name "$CONTAINER" --name reports/q3-report.txt --account-name "$SA" --account-key "$KEY" -o tsv)"
echo "$URL?$SAS" > "$HERE/sas.txt"
echo "  Partner link saved to sas.txt (never commit it)."

say "5. Lifecycle management: Cool at 30 days, Archive at 90, delete at 365"
az storage account management-policy create --account-name "$SA" --resource-group "$RG" \
  --policy @"$HERE/policy.json" -o none

echo "Done. Next: ./verify.sh"
