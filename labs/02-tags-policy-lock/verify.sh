#!/usr/bin/env bash
# Lab 02 checks: the policy blocks untagged resources, allows tagged ones, and the lock blocks deletion.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab02"
require_login
SFX="$(suffix)"

say "Checking lab 02"
RG_ID="$(az group show --name "$RG" --query id -o tsv)"
expect "policy assignment exists at RG scope" \
  "$(az policy assignment list --scope "$RG_ID" --query "[?name=='require-costcenter-tag'] | length(@)" -o tsv)" "1"

expect_fail "an UNTAGGED storage account is denied by policy" \
  az storage account create --name "stnotag${SFX}" --resource-group "$RG" --location "$LOC" --sku Standard_LRS

check "a TAGGED storage account is allowed" \
  az storage account create --name "sttag${SFX}" --resource-group "$RG" --location "$LOC" \
  --sku Standard_LRS --tags CostCenter=FIN-001

expect "CanNotDelete lock is on the group" \
  "$(az lock list --resource-group "$RG" --query "[?level=='CanNotDelete'] | length(@)" -o tsv)" "1"

expect_fail "deleting the locked storage account is blocked" \
  az storage account delete --name "sttag${SFX}" --resource-group "$RG" --yes

echo
echo "If the untagged check FAILED, the policy is not enforcing yet. Wait 10 minutes and run again."
summary
