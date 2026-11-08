#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab10"
ZONE="privatelink.blob.core.windows.net"
require_login
SA="stlab10$(suffix)"
HOST="${SA}.blob.core.windows.net"

say "Checking lab 10"
expect "public network access is Disabled" \
  "$(az storage account show -n "$SA" -g "$RG" --query publicNetworkAccess -o tsv)" "Disabled"
expect "private endpoint connection is Approved" \
  "$(az network private-endpoint show -g "$RG" -n "pe-${SA}-blob" --query 'privateLinkServiceConnections[0].privateLinkServiceConnectionState.status' -o tsv)" "Approved"
expect "private DNS zone has an A record for the account" \
  "$(az network private-dns record-set a list -g "$RG" --zone-name "$ZONE" --query "[?name=='$SA'] | length(@)" -o tsv)" "1"

say "Name resolution from INSIDE the VNet should return a 10.60.2.x address"
IN="$(az vm run-command invoke -g "$RG" -n vm-test01 --command-id RunShellScript \
  --scripts "getent hosts $HOST | awk '{print \$1}'" --query "value[0].message" -o tsv)"
if [[ "$IN" == *"10.60.2."* ]]; then pass "inside the VNet, $HOST resolves to a private IP"; else fail "expected 10.60.2.x, got: $IN"; fi

say "From OUTSIDE (your shell), the public path is refused"
# Must be the NETWORK rule refusing it (403 AuthorizationFailure). A 409 only means anonymous blob
# access is off, which would happen even if the account were still open to the internet.
RESP="$(curl -s -w '\n%{http_code}' "https://${HOST}/?comp=list")"
CODE="$(tail -n1 <<< "$RESP")"
if [[ "$CODE" == "403" && "$RESP" == *AuthorizationFailure* ]]; then
  pass "public request refused by the network rule (403 AuthorizationFailure)"
else
  fail "expected 403 AuthorizationFailure from outside, got $CODE: $(head -c 150 <<< "$RESP")"
fi
summary
