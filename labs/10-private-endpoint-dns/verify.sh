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
CODE="$(curl -s -o /dev/null -w '%{http_code}' "https://${HOST}/?comp=list")"
if [[ "$CODE" == "403" || "$CODE" == "409" ]]; then pass "public request refused ($CODE)"; else fail "expected 403/409 from outside, got $CODE"; fi
summary
