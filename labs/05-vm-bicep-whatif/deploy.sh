#!/usr/bin/env bash
# Lab 05: Preview a Bicep deployment with what-if, deploy it, then modify it (tag, data disk) and preview each change.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab05"
HERE="$(cd "$(dirname "$0")" && pwd)"
require_login

# Use your existing SSH key, or create one.
KEYFILE="$HOME/.ssh/id_rsa.pub"
[[ -f "$KEYFILE" ]] || ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" -q
PUBKEY="$(cat "$KEYFILE")"

say "1. Resource group"
az group create --name "$RG" --location "$LOC" --tags lab=05 -o none

say "2. WHAT-IF: preview what Azure would create (nothing is deployed yet)"
az deployment group what-if --resource-group "$RG" --template-file "$HERE/main.bicep" \
  --parameters adminPublicKey="$PUBKEY"

say "3. Deploy for real"
az deployment group create --name lab05-v1 --resource-group "$RG" \
  --template-file "$HERE/main.bicep" --parameters adminPublicKey="$PUBKEY" \
  --query "properties.outputs" -o json

say "4. Change one thing (env tag) and preview again: what-if shows only the difference"
az deployment group what-if --resource-group "$RG" --template-file "$HERE/main.bicep" \
  --parameters adminPublicKey="$PUBKEY" tags='{"lab":"05","env":"test"}'

say "5. Modify the deployment: add a data disk (template change), preview, then deploy v2"
az deployment group what-if --resource-group "$RG" --template-file "$HERE/main.bicep" \
  --parameters adminPublicKey="$PUBKEY" addDataDisk=true
az deployment group create --name lab05-v2 --resource-group "$RG" \
  --template-file "$HERE/main.bicep" --parameters adminPublicKey="$PUBKEY" addDataDisk=true \
  --query "properties.outputs" -o json

echo "Done. Next: ./verify.sh"
