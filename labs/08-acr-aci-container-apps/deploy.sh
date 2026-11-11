#!/usr/bin/env bash
# Lab 08: Put an image in your private registry and run it two ways: ACI (simple) and Container Apps (scales).
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab08"
SRC_IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
require_login
SFX="$(suffix)"
ACR="acrlab08${SFX}"
ENV="cae-lab08"

say "1. Private registry (Basic) with the admin user enabled for this lab"
az group create --name "$RG" --location "$LOC" --tags lab=08 -o none
az acr create --name "$ACR" --resource-group "$RG" --location "$LOC" --sku Basic --admin-enabled true -o none

say "2. Import a public image into YOUR registry (no Docker needed)"
az acr import --name "$ACR" --source "$SRC_IMAGE" --image hello:v1 --force
SERVER="$(az acr show --name "$ACR" --query loginServer -o tsv)"
ACR_USER="$(az acr credential show --name "$ACR" --query username -o tsv)"
ACR_PASS="$(az acr credential show --name "$ACR" --query 'passwords[0].value' -o tsv)"

say "3. Azure Container Instances: one container, public IP, 1 vCPU / 1.5 GiB"
az container create --resource-group "$RG" --name aci-hello --image "$SERVER/hello:v1" \
  --os-type Linux --cpu 1 --memory 1.5 --ports 80 --ip-address Public \
  --dns-name-label "aci-hello-${SFX}" \
  --registry-login-server "$SERVER" --registry-username "$ACR_USER" --registry-password "$ACR_PASS" -o none

say "4. Azure Container Apps: environment + app with external ingress, scale 0 to 3"
az extension add --name containerapp --upgrade -o none   # newest features; avoids an install prompt mid-script
# Create the environment only once. Without a workspace ID, every create makes a NEW Log Analytics
# workspace with a random name, so a re-run would leave extra workspaces behind. This lab doesn't need logs.
if ! az containerapp env show --name "$ENV" --resource-group "$RG" -o none 2>/dev/null; then
  az containerapp env create --name "$ENV" --resource-group "$RG" --location "$LOC" --logs-destination none -o none
fi
# A brand-new environment sometimes rejects the first create ("image ... invalid or missing")
# while it is still settling. Try up to three times before giving up.
for try in 1 2 3; do
  if az containerapp create --name ca-hello --resource-group "$RG" --environment "$ENV" \
    --image "$SERVER/hello:v1" --registry-server "$SERVER" \
    --registry-username "$ACR_USER" --registry-password "$ACR_PASS" \
    --ingress external --target-port 80 --min-replicas 0 --max-replicas 3 -o none; then
    break
  fi
  [[ "$try" -eq 3 ]] && { echo "Container app create failed three times. Run ./deploy.sh again in a few minutes."; exit 1; }
  echo "  Container app create failed (try $try of 3). Waiting 45 seconds, then trying again."
  sleep 45
done

say "5. Change scaling: always 1 warm replica, up to 5, add a replica per 20 concurrent requests"
az containerapp update --name ca-hello --resource-group "$RG" \
  --min-replicas 1 --max-replicas 5 \
  --scale-rule-name http-rule --scale-rule-type http --scale-rule-http-concurrency 20 -o none

echo
echo "ACI:            http://$(az container show -g "$RG" -n aci-hello --query ipAddress.fqdn -o tsv)"
echo "Container Apps: https://$(az containerapp show -g "$RG" -n ca-hello --query properties.configuration.ingress.fqdn -o tsv)"
echo "Next: ./verify.sh"
