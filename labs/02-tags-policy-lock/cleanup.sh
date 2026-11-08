#!/usr/bin/env bash
# Lab 02 cleanup: a lock must be removed before anything under it can be deleted.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab02"
require_login
RG_ID="$(az group show --name "$RG" --query id -o tsv 2>/dev/null || true)"
az lock delete --name lock-no-delete --resource-group "$RG" 2>/dev/null || true
if [[ -n "$RG_ID" ]]; then az policy assignment delete --name require-costcenter-tag --scope "$RG_ID" 2>/dev/null || true; fi
echo "Lock removed first, then the policy assignment, then the group:"
delete_group "$RG" || { echo "Is the lock still there? az lock list -g $RG" >&2; exit 1; }
