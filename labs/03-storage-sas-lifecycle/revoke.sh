#!/usr/bin/env bash
# Lab 03: revoke the partner's access by deleting the stored access policy.
# Every SAS that points at the policy stops working. The account key is untouched.
# Run ./deploy.sh again to re-create the policy and a fresh link.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab03"
CONTAINER="partner-share"
POLICY_NAME="partner-read-30d"
require_login
SA="stlab03$(suffix)"
HERE="$(cd "$(dirname "$0")" && pwd)"
LINK="$(cat "$HERE/sas.txt")"
KEY="$(az storage account keys list --account-name "$SA" --resource-group "$RG" --query '[0].value' -o tsv)"
code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

say "Revoking: delete the stored access policy"
az storage container policy delete --container-name "$CONTAINER" --name "$POLICY_NAME" \
  --account-name "$SA" --account-key "$KEY" -o none
echo "  waiting up to 60 seconds for the change to apply"
REVOKED="$(code "$LINK")"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do [[ "$REVOKED" == "403" ]] && break; sleep 5; REVOKED="$(code "$LINK")"; done
if [[ "$REVOKED" == "403" ]]; then pass "the same SAS link is now refused (403)"; else fail "expected 403 after revoke, got $REVOKED"; fi
summary
