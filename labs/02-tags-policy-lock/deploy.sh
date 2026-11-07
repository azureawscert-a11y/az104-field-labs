#!/usr/bin/env bash
# Lab 02: Require a CostCenter tag with Azure Policy, then protect the group with a delete lock.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab02"
ASSIGNMENT="require-costcenter-tag"
TAG="CostCenter"

require_login

say "1. Resource group, tagged the way finance wants"
az group create --name "$RG" --location "$LOC" --tags "$TAG=FIN-001" owner=it -o none
RG_ID="$(az group show --name "$RG" --query id -o tsv)"

say "2. Find the built-in policy by its display name (no hard-coded IDs)"
POLICY="$(az policy definition list \
  --query "[?displayName=='Require a tag on resources'].name | [0]" -o tsv)"
echo "  Built-in definition: $POLICY"

say "3. Assign it at resource group scope with the tag name as a parameter"
az policy assignment create --name "$ASSIGNMENT" \
  --display-name "Require $TAG tag on resources (lab02)" \
  --policy "$POLICY" --scope "$RG_ID" \
  --params "{\"tagName\": {\"value\": \"$TAG\"}}" -o none

say "4. Add a CanNotDelete lock on the resource group"
az lock create --name lock-no-delete --lock-type CanNotDelete \
  --resource-group "$RG" --notes "Ticket INC-1002: finance resources" -o none

echo
echo "Policy assignments can take 5 to 30 minutes to start enforcing."
echo "Wait a few minutes, then run ./verify.sh"
