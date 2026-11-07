#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab09"
require_login
HUB_IP="$(az vm show -g "$RG" -n vm-hub01 --show-details --query privateIps -o tsv)"
APP_IP="$(az vm show -g "$RG" -n vm-app01 --show-details --query privateIps -o tsv)"

say "Checking lab 09 (hub $HUB_IP, app $APP_IP)"
expect "hub-to-spoke1 peering is Connected" \
  "$(az network vnet peering show -g "$RG" --vnet-name vnet-hub -n hub-to-spoke1 --query peeringState -o tsv)" "Connected"
expect "spoke1-to-hub peering is Connected" \
  "$(az network vnet peering show -g "$RG" --vnet-name vnet-spoke1 -n spoke1-to-hub --query peeringState -o tsv)" "Connected"

say "IP flow verify: would SSH from the hub VM reach the app VM?"
expect "SSH hub -> app is Allowed" \
  "$(az network watcher test-ip-flow -g "$RG" --vm vm-app01 --direction Inbound --protocol TCP \
     --local "${APP_IP}:22" --remote "${HUB_IP}:50000" --query access -o tsv)" "Allow"
expect "SSH from a spoke address -> app is Denied" \
  "$(az network watcher test-ip-flow -g "$RG" --vm vm-app01 --direction Inbound --protocol TCP \
     --local "${APP_IP}:22" --remote "10.20.1.200:50000" --query access -o tsv)" "Deny"

say "Next hop: how does the app VM reach the hub?"
expect "next hop to the hub is VNetPeering" \
  "$(az network watcher show-next-hop -g "$RG" --vm vm-app01 --source-ip "$APP_IP" --dest-ip "$HUB_IP" --query nextHopType -o tsv)" "VNetPeering"

say "Real traffic: ping the app VM from the hub VM"
OUT="$(az vm run-command invoke -g "$RG" -n vm-hub01 --command-id RunShellScript \
  --scripts "ping -c 3 -W 2 $APP_IP | tail -2" --query "value[0].message" -o tsv)"
if [[ "$OUT" == *" 0% packet loss"* ]]; then pass "hub VM can ping app VM over the peering"; else fail "ping failed: $OUT"; fi
summary
