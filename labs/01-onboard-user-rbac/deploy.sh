#!/usr/bin/env bash
# Lab 01: Onboard a new hire. User + group + Reader on one resource group.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab01"
GROUP="grp-finance-readers"
USER_NAME="priya.lab01"
DISPLAY="Priya Sharma (lab)"

require_login
DOMAIN="$(tenant_domain)"
UPN="${USER_NAME}@${DOMAIN}"
# A random temporary password. The user must change it at first sign-in.
PASS="Lab-$(openssl rand -hex 6)-Az!"

say "1. Resource group the team will read"
az group create --name "$RG" --location "$LOC" --tags lab=01 owner=finance -o none

say "2. Create the user (skip if it already exists)"
if USER_ID="$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null)"; then
  echo "  User already exists. To give her a new temporary password:"
  echo "  az ad user update --id $UPN --password '<new password>' --force-change-password-next-sign-in true"
else
  # Take the ID from the create itself: a lookup right after creating can miss the new user.
  USER_ID="$(az ad user create --display-name "$DISPLAY" --user-principal-name "$UPN" \
    --password "$PASS" --force-change-password-next-sign-in true --query id -o tsv)"
  echo "  Temporary password (give it to the user privately): $PASS"
fi

say "3. Create the security group and add the user"
GROUP_ID="$(lab_group_ensure "$GROUP")"
if [[ "$(az ad group member check --group "$GROUP_ID" --member-id "$USER_ID" --query value -o tsv)" != "true" ]]; then
  az ad group member add --group "$GROUP_ID" --member-id "$USER_ID"
fi

say "4. Give the GROUP (not the user) Reader on the resource group"
RG_ID="$(az group show --name "$RG" --query id -o tsv)"
# New groups can take a minute to replicate. assign_role retries, then stops with a clear error if you lack rights.
assign_role "$GROUP_ID" Group "Reader" "$RG_ID"

echo
echo "Done. User: $UPN  Group: $GROUP  Role: Reader  Scope: $RG"
echo "Next: ./verify.sh   (a new role assignment can take up to 10 minutes to show up in the portal)"
