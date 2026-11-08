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

# expect_denied "description" PATTERN command args...
# PASS only if the command fails AND its error contains PATTERN (e.g. RequestDisallowedByPolicy).
# A failure for any other reason (name taken, quota, typo) is a FAIL, so a broken lab can't look healthy.
expect_denied() {
  local desc="$1" pattern="$2" out; shift 2
  if out="$("$@" 2>&1)"; then
    fail "$desc (it was allowed)"
  elif grep -q "$pattern" <<< "$out"; then
    pass "$desc"
  else
    fail "$desc (failed for another reason: $(grep -m1 -E 'ERROR|Code|Message' <<< "$out" | cut -c1-150))"
  fi
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
  local d
  d="$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" \
    --query "value[?isDefault].id | [0]" -o tsv)"
  [[ -n "$d" ]] || { echo "ERROR: could not read your tenant's default domain from Microsoft Graph" >&2; exit 1; }
  echo "$d"
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
  local n
  n="$(az role assignment list --assignee-object-id "$oid" --role "$role" --scope "$scope" --query 'length(@)' -o tsv 2>/dev/null)"
  if [[ "$n" != "1" ]]; then
    echo "ERROR: could not assign '$role'. You need Owner or User Access Administrator on $scope." >&2
    echo "Run this to see the real error:" >&2
    echo "  az role assignment create --assignee-object-id $oid --assignee-principal-type $ptype --role \"$role\" --scope $scope" >&2
    exit 1
  fi
}

# backup_enable_once RG VAULT VM [POLICY]  -> enables VM backup only if the VM is not already protected (safe to re-run)
backup_enable_once() {
  local rg="$1" vault="$2" vm="$3" policy="${4:-DefaultPolicy}" active deleted
  # Capture first: a failing $( ) inside [[ ]] would be silently ignored.
  active="$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM \
    --query "[?properties.friendlyName=='$vm' && properties.isScheduledForDeferredDelete!=\`true\`] | length(@)" -o tsv)" || return 1
  deleted="$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM \
    --query "[?properties.friendlyName=='$vm' && properties.isScheduledForDeferredDelete==\`true\`] | length(@)" -o tsv)" || return 1
  if [[ "$active" != "0" ]]; then
    echo "  $vm is already protected, skipping"
  elif [[ "$deleted" != "0" ]]; then
    echo "  $vm has a soft-deleted backup in $vault. Bring it back first, then run deploy again:" >&2
    echo "  az backup protection undelete -g $rg --vault-name $vault -c $vm -i $vm --backup-management-type AzureIaasVM --workload-type VM" >&2
    return 1
  else
    az backup protection enable-for-vm -g "$rg" --vault-name "$vault" --vm "$vm" --policy-name "$policy" -o none
  fi
}

# backup_cleanup RG VAULT VM
# Waits for running jobs, stops protection and deletes the backup data, then tries to delete the vault.
# Since 2026 vaults are "secure by default": soft delete is always on, so deleted backup data is kept
# for 14 days (no charge in that window) and nobody can purge it early. "vault delete --force" still
# works: Azure moves the vault and its soft-deleted backup into a 14-day soft-deleted state (tested Nov 2026).
# Returns 0 = vault gone, 2 = Azure refused and kept the vault (fallback path), 1 = something is wrong.
backup_cleanup() {
  local rg="$1" vault="$2" vm="$3" job active
  if ! az backup vault show -g "$rg" -n "$vault" -o none 2>/dev/null; then
    echo "  vault $vault not found, nothing to remove"; return 0
  fi
  for job in $(az backup job list -g "$rg" --vault-name "$vault" --status InProgress --query "[].name" -o tsv); do
    echo "  waiting for running backup job $job (this can take 20 to 60 minutes)"
    az backup job wait -g "$rg" --vault-name "$vault" --name "$job" -o none
  done
  active="$(az backup item list -g "$rg" --vault-name "$vault" --backup-management-type AzureIaasVM \
          --query "[?properties.friendlyName=='$vm' && properties.isScheduledForDeferredDelete!=\`true\`] | length(@)" -o tsv)"
  if [[ "$active" != "0" ]]; then
    echo "  stopping protection and deleting backup data (it moves to soft delete for 14 days)"
    az backup protection disable -g "$rg" --vault-name "$vault" --container-name "$vm" --item-name "$vm" \
      --backup-management-type AzureIaasVM --delete-backup-data true --yes -o none || return 1
  fi
  if az backup vault delete -g "$rg" --name "$vault" --yes --force -o none 2>/dev/null; then
    echo "  vault $vault deleted"; return 0
  fi
  if az backup vault show -g "$rg" -n "$vault" -o none 2>/dev/null; then return 2; fi
  return 0
}

# delete_all_but_vault RG -> deletes every resource in RG except the Recovery Services vault.
# Used while soft delete keeps the vault. Runs a few passes because some resources depend on others.
delete_all_but_vault() {
  local rg="$1" ids vms i
  for i in 1 2 3 4 5; do
    ids="$(az resource list -g "$rg" --query "[?type!='Microsoft.RecoveryServices/vaults'].id" -o tsv)"
    [[ -z "$ids" ]] && { echo "  everything except the vault is deleted"; return 0; }
    vms="$(grep -i '/virtualMachines/' <<< "$ids" || true)"
    # shellcheck disable=SC2086  # word splitting on IDs is intended
    [[ -n "$vms" ]] && az vm delete --ids $vms --yes -o none 2>/dev/null
    echo "  pass $i: deleting $(wc -l <<< "$ids") resource(s)"
    # shellcheck disable=SC2086
    az resource delete --ids $ids -o none 2>/dev/null || true
  done
  echo "  some resources are still there: az resource list -g $rg -o table" >&2
  return 1
}

# finish_vault_cleanup RG VAULT -> prints what happens next when soft delete keeps the vault
finish_vault_cleanup() {
  local when
  when="$(date -u -d '+15 days' '+%B %d' 2>/dev/null || date -u -v+15d '+%B %d')"
  echo
  echo "Azure keeps vault $2 for 14 days because its backups are soft-deleted (secure by default)."
  echo "That costs nothing. Everything else in $1 is deleted."
  echo "Run ./cleanup.sh again on or after $when to delete the vault and the resource group."
}
