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

# group_id_exact NAME -> prints the object ID of the ONE Entra group with exactly this display name
# (empty if there is none). "az ad group list --display-name" and "show --group" match name PREFIXES,
# so they could pick up an unrelated group like "grp-x-old". Stops if several groups share the name.
group_id_exact() {
  local ids n
  ids="$(az ad group list --filter "displayName eq '$1'" --query "[].id" -o tsv)" || return 1
  n="$(grep -c . <<< "$ids" || true)"
  if [[ "$n" -gt 1 ]]; then
    echo "ERROR: $n Entra groups are named '$1'. Delete or rename the extras, then run again." >&2
    return 1
  fi
  echo "$ids"
}

# Groups the labs create carry this description, so a lab never changes or deletes someone else's group.
LAB_GROUP_MARK="Created by az104-field-labs"

# lab_group_ensure NAME -> prints the ID of the lab's own Entra group, creating it if needed.
# Stops if a group with this exact name exists but was not created by these labs.
lab_group_ensure() {
  local id desc
  id="$(group_id_exact "$1")" || return 1
  if [[ -z "$id" ]]; then
    az ad group create --display-name "$1" --mail-nickname "$1" --description "$LAB_GROUP_MARK" --query id -o tsv
    return
  fi
  desc="$(az ad group show --group "$id" --query description -o tsv)" || return 1
  if [[ "$desc" != "$LAB_GROUP_MARK" ]]; then
    echo "ERROR: a group named '$1' already exists and was not created by these labs." >&2
    echo "The lab will not change it. Rename that group, or change the group name at the top of the script." >&2
    return 1
  fi
  echo "$id"
}

# lab_group_id NAME -> prints the ID only if the group exists AND was created by these labs (for cleanup).
lab_group_id() {
  local id desc
  id="$(group_id_exact "$1")" || return 1
  [[ -z "$id" ]] && return 0
  desc="$(az ad group show --group "$id" --query description -o tsv)" || return 1
  if [[ "$desc" == "$LAB_GROUP_MARK" ]]; then echo "$id"
  else echo "  group '$1' was not created by these labs: leaving it alone" >&2; fi
}

# delete_group RG -> starts deleting a resource group. Already gone is fine; any other error returns 1.
# A failed lookup (for example an expired sign-in) is an error, never "already gone".
delete_group() {
  local exists out
  exists="$(az group exists -n "$1")" || { echo "Could not check whether $1 exists. Are you signed in? (az login)" >&2; return 1; }
  case "$exists" in
    false) echo "  $1 is already gone"; return 0 ;;
    true) ;;
    *) echo "Unexpected answer '$exists' when checking $1." >&2; return 1 ;;
  esac
  if out="$(az group delete --name "$1" --yes --no-wait 2>&1)"; then echo "Cleanup started for $1."; return 0; fi
  echo "$out" >&2
  echo "Could not delete $1. Read the error above, fix it, and run ./cleanup.sh again." >&2
  return 1
}

# delete_vm_restore_points VM_RESOURCE_ID -> deletes that VM's instant-restore snapshots (restore point
# collections). Azure Backup keeps them in AzureBackupRG_<region>_1. Unlike soft-deleted vault data they
# are BILLED, and stopping protection does not remove them. Only collections whose source is exactly
# this VM are deleted (names alone could match another VM with the same or a longer name).
delete_vm_restore_points() {
  local vmid="$1" ids id src n=0
  ids="$(az resource list --resource-type Microsoft.Compute/restorePointCollections \
        --query "[?starts_with(name, 'AzureBackup_')].id" -o tsv)" || return 1
  for id in $ids; do
    src="$(az resource show --ids "$id" --query properties.source.id -o tsv)" || return 1
    if [[ -n "$src" && "${src,,}" == "${vmid,,}" ]]; then
      az resource delete --ids "$id" -o none || return 1
      n=$((n + 1))
    fi
  done
  if [[ $n -gt 0 ]]; then
    echo "  deleted $n instant-restore snapshot collection(s) of this VM (billed, even while the backup is soft-deleted)"
  fi
  return 0
}

# pe_ip RG PRIVATE_ENDPOINT -> prints the private endpoint's own IP (from its network interface)
pe_ip() {
  local nic
  nic="$(az network private-endpoint show -g "$1" -n "$2" --query "networkInterfaces[0].id" -o tsv)" || return 1
  az network nic show --ids "$nic" --query "ipConfigurations[0].privateIPAddress" -o tsv
}

# backup_state RG VAULT VM -> prints the protection state of the VM's ACTIVE backup item
# (Protected, IRPending = first backup not done yet, ProtectionStopped...), ignoring soft-deleted items.
backup_state() {
  az backup item list -g "$1" --vault-name "$2" --backup-management-type AzureIaasVM \
    --query "[?properties.friendlyName=='$3' && properties.isScheduledForDeferredDelete!=\`true\`] | [0].properties.protectionState" -o tsv
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
# Since 2026 vaults are "secure by default": soft delete is always on, so deleted vault backup data is
# kept for 14 days at no charge. The VM's instant-restore SNAPSHOTS are different: they are billed and
# must be deleted separately (delete_vm_restore_points). "vault delete --force" still works: Azure moves
# the vault and its soft-deleted backup into a 14-day soft-deleted state (tested Nov 2026).
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
  delete_vm_restore_points "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.Compute/virtualMachines/$vm" || return 1
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
    ids="$(az resource list -g "$rg" --query "[?type!='Microsoft.RecoveryServices/vaults'].id" -o tsv)" || return 1
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
  echo "The soft-deleted backup data costs nothing. Everything else in $1 is deleted."
  echo "Run ./cleanup.sh again on or after $when to delete the vault and the resource group."
}
