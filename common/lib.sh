#!/usr/bin/env bash
# Shared helpers for az104-field-labs. Source this file; do not run it.
# shellcheck disable=SC2034

FAILS=0
# Region and VM sizes. tools/check-region.sh finds values that work in YOUR subscription
# and saves them to ~/.az104labs. Anything you set on the command line wins, for example:
#   LOC=eastus2 ./deploy.sh
# shellcheck disable=SC1091
[[ -f "$HOME/.az104labs" ]] && source "$HOME/.az104labs"
LOC="${LOC:-canadacentral}"
VM_SIZE="${VM_SIZE:-Standard_B2ats_v2}"          # small VM used by labs 05, 09, 10, 12 and the capstone
VM_SIZE_BIG="${VM_SIZE_BIG:-Standard_B2als_v2}"  # the size lab 06 resizes up to

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILS=$((FAILS + 1)); }

# check "description" command args...   -> PASS if the command succeeds
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# expect "description" "actual" "expected"  -> PASS if they match
expect() {
  if [[ "$2" == "$3" ]]; then pass "$1 ($2)"; else fail "$1 (got '$2', expected '$3')"; fi
}

# expect_fail "description" command args...  -> PASS if the command FAILS (used to prove a block works)
expect_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$desc"; else pass "$desc"; fi
}

summary() {
  echo
  if [[ "$FAILS" -eq 0 ]]; then
    printf '\033[32mAll checks passed.\033[0m Explain what you built, then run ./cleanup.sh\n'
  else
    printf '\033[31m%s check(s) failed.\033[0m Read the FAIL lines, fix, and run verify.sh again.\n' "$FAILS"
    exit 1
  fi
}

require_login() {
  if ! az account show >/dev/null 2>&1; then
    echo "Not signed in. Run: az login   (Cloud Shell is already signed in)"
    exit 1
  fi
  echo "Subscription: $(az account show --query name -o tsv)"
}

# A short suffix that is stable for your subscription, so global names (storage, web apps, ACR) are unique.
suffix() {
  az account show --query id -o tsv | tr -d '-' | cut -c1-6
}

# Default verified domain of your tenant, for new user names (user@yourtenant.onmicrosoft.com)
tenant_domain() {
  az rest --method get --url "https://graph.microsoft.com/v1.0/domains" \
    --query "value[?isDefault].id | [0]" -o tsv
}

# assign_role "objectId" "PrincipalType" "Role name" "scope"
# Retries while Entra ID replicates a new user or group, then fails loudly if it never worked.
assign_role() {
  local oid="$1" ptype="$2" role="$3" scope="$4" i
  for i in 1 2 3 4 5 6; do
    if az role assignment create --assignee-object-id "$oid" --assignee-principal-type "$ptype" \
         --role "$role" --scope "$scope" -o none 2>/dev/null; then
      return 0
    fi
    echo "  waiting for Entra ID replication ($i/6)"; sleep 15
  done
  if [[ "$(az role assignment list --assignee "$oid" --role "$role" --scope "$scope" --query 'length(@)' -o tsv)" == "0" ]]; then
    echo "ERROR: could not assign '$role'. You need Owner or User Access Administrator on $scope." >&2
    echo "Run this to see the real error:" >&2
    echo "  az role assignment create --assignee-object-id $oid --assignee-principal-type $ptype --role \"$role\" --scope $scope" >&2
    exit 1
  fi
}

# backup_enable_once RG VAULT VM [POLICY]  -> enables VM backup only if the VM is not already protected (safe to re-run)
backup_enable_once() {
  local rg="$1" vault="$2" vm="$3" policy="${4:-DefaultPolicy}"
  if [[ "$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM \
          --query "[?properties.friendlyName=='$vm'] | length(@)" -o tsv)" == "0" ]]; then
    az backup protection enable-for-vm -g "$rg" --vault-name "$vault" --vm "$vm" --policy-name "$policy" -o none
  else
    echo "  $vm is already protected, skipping"
  fi
}

# backup_cleanup RG VAULT VM  -> waits for running jobs, removes backup data and the vault, and fails if anything is left
backup_cleanup() {
  local rg="$1" vault="$2" vm="$3" job left
  if ! az backup vault show -g "$rg" -n "$vault" -o none 2>/dev/null; then
    echo "  vault $vault not found, nothing to remove"; return 0
  fi
  for job in $(az backup job list -g "$rg" --vault-name "$vault" --status InProgress --query "[].name" -o tsv); do
    echo "  waiting for running backup job $job (this can take 20 to 60 minutes)"
    az backup job wait -g "$rg" --vault-name "$vault" --name "$job" -o none
  done
  if [[ "$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM \
          --query "[?properties.friendlyName=='$vm'] | length(@)" -o tsv)" != "0" ]]; then
    az backup protection disable -g "$rg" --vault-name "$vault" --container-name "$vm" --item-name "$vm" \
      --backup-management-type AzureIaasVM --delete-backup-data true --yes -o none
  fi
  left="$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM --query 'length(@)' -o tsv)"
  if [[ "$left" != "0" ]]; then
    echo "ERROR: $left backup item(s) still in $vault. Fix that before deleting the vault, then run cleanup.sh again." >&2
    return 1
  fi
  az backup vault delete -g "$rg" --name "$vault" --yes -o none
}
