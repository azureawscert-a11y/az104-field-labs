#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab08"
require_login
ACR="acrlab08$(suffix)"
say "Checking lab 08"
SERVER="$(az acr show --name "$ACR" --query loginServer -o tsv)"
expect "image hello:v1 is in your registry" \
  "$(az acr repository show-tags --name "$ACR" --repository hello --query "[?@=='v1'] | length(@)" -o tsv 2>/dev/null)" "1"
expect "ACI runs the image from YOUR registry" \
  "$(az container show -g "$RG" -n aci-hello --query "containers[0].image" -o tsv)" "$SERVER/hello:v1"
expect "Container App runs the image from YOUR registry" \
  "$(az containerapp show -g "$RG" -n ca-hello --query "properties.template.containers[0].image" -o tsv)" "$SERVER/hello:v1"
expect "ACI container group is Running" \
  "$(az container show -g "$RG" -n aci-hello --query instanceView.state -o tsv)" "Running"
ACI="$(az container show -g "$RG" -n aci-hello --query ipAddress.fqdn -o tsv)"
expect "ACI answers on port 80" "$(curl -s -o /dev/null -w '%{http_code}' "http://$ACI")" "200"
CA="$(az containerapp show -g "$RG" -n ca-hello --query properties.configuration.ingress.fqdn -o tsv)"
expect "Container App answers over HTTPS" "$(curl -s -o /dev/null -w '%{http_code}' "https://$CA")" "200"
expect "Container App min replicas = 1" \
  "$(az containerapp show -g "$RG" -n ca-hello --query properties.template.scale.minReplicas -o tsv)" "1"
expect "Container App max replicas = 5" \
  "$(az containerapp show -g "$RG" -n ca-hello --query properties.template.scale.maxReplicas -o tsv)" "5"
expect "HTTP scale rule at 20 concurrent requests" \
  "$(az containerapp show -g "$RG" -n ca-hello --query "properties.template.scale.rules[?name=='http-rule'].http.metadata.concurrentRequests | [0]" -o tsv)" "20"
summary
