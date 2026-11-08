#!/usr/bin/env bash
# Lab 03 checks: link works with SAS and fails without it. Safe to run as often as you like.
# To prove revocation, run ./revoke.sh afterwards.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"

RG="rg-az104-lab03"
require_login
SA="stlab03$(suffix)"
HERE="$(cd "$(dirname "$0")" && pwd)"
LINK="$(cat "$HERE/sas.txt")"
PLAIN="${LINK%%\?*}"

code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

say "Checking lab 03"
expect "blob public access is disabled" \
  "$(az storage account show --name "$SA" --resource-group "$RG" --query allowBlobPublicAccess -o tsv)" "false"
expect "minimum TLS version is TLS1_2" \
  "$(az storage account show --name "$SA" --resource-group "$RG" --query minimumTlsVersion -o tsv)" "TLS1_2"
expect "HTTPS-only traffic is enforced" \
  "$(az storage account show --name "$SA" --resource-group "$RG" --query enableHttpsTrafficOnly -o tsv)" "true"
# A new stored access policy can take up to 30 seconds to apply, so retry for a short while.
WITH="$(code "$LINK")"
for _ in 1 2 3 4 5 6; do [[ "$WITH" == "200" ]] && break; sleep 5; WITH="$(code "$LINK")"; done
expect "link WITH the SAS downloads the file" "$WITH" "200"
NOSAS="$(code "$PLAIN")"
# 409 = public access is off for the account, 403/404 = refused. 000 would mean curl itself failed.
if [[ "$NOSAS" =~ ^(403|404|409)$ ]]; then pass "link WITHOUT the SAS is refused ($NOSAS)"; else fail "link WITHOUT the SAS: expected 403, 404 or 409, got $NOSAS"; fi
expect "lifecycle rule exists" \
  "$(az storage account management-policy show --account-name "$SA" --resource-group "$RG" --query 'policy.rules[0].name' -o tsv)" \
  "reports-to-cool-then-delete"

summary
