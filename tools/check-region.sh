#!/usr/bin/env bash
# Finds a region and VM sizes that YOUR subscription can use, then saves them for every lab.
#
# Why: new subscriptions often have 0 quota for some VM families, and busy regions block
# small sizes for new customers ("SkuNotAvailable"). App Service Standard (S1) can also have
# 0 quota in a region. This script checks before you spend time on a lab that would fail.
#
# How: "az vm create --validate" runs Azure's preflight checks (size available? quota left?)
# WITHOUT creating anything. App Service has no free preflight, so the script creates an
# S1 plan and deletes it a few seconds later (costs a fraction of a cent).
#
# Usage: bash tools/check-region.sh              tries your LOC first, then other regions
#        bash tools/check-region.sh eastus2      checks only eastus2
# Result: ~/.az104labs, read by every lab. Delete that file to go back to the defaults.
set -uo pipefail
CONF="$HOME/.az104labs"
CHECK_RG="rg-az104-regioncheck"

if [[ $# -gt 0 ]]; then
  REGIONS="$*"
else
  REGIONS="${LOC:-canadacentral} canadacentral canadaeast eastus2 eastus westus2 westus3 centralus northeurope westeurope uksouth australiaeast"
fi
# small size + the bigger size lab 06 resizes to, cheapest first
PAIRS=(
  "Standard_B2ats_v2 Standard_B2als_v2"
  "Standard_B2s Standard_B2ms"
  "Standard_D2als_v6 Standard_D2as_v6"
  "Standard_D2as_v5 Standard_D2s_v5"
  "Standard_D2as_v4 Standard_D2s_v4"
)

az account show -o none 2>/dev/null || { echo "Not signed in. Run: az login"; exit 1; }
echo "Subscription: $(az account show --query name -o tsv)"
FIRST="$(echo "$REGIONS" | awk '{print $1}')"
# If a previous run's group is still being deleted, wait for it to go first.
az group wait --deleted --name "$CHECK_RG" 2>/dev/null || true
az group create --name "$CHECK_RG" --location "$FIRST" --tags purpose=region-check -o none \
  || { echo "Could not create the test group $CHECK_RG. Read the error above."; exit 1; }
# Always remove the test group, even if you press Ctrl+C (the App Service test creates a paid S1 plan for a few seconds).
trap 'az group delete --name "$CHECK_RG" --yes --no-wait 2>/dev/null' EXIT

vm_ok() {  # vm_ok REGION SIZE -> 0 if Azure would accept this VM
  local out
  if out="$(az vm create -g "$CHECK_RG" -n vm-check -l "$1" --image Ubuntu2204 --size "$2" \
        --admin-username azureuser --generate-ssh-keys --public-ip-address "" --nsg "" \
        --validate 2>&1)"; then
    return 0
  fi
  local why
  why="$(grep -oE 'SkuNotAvailable|QuotaExceeded|OperationNotAllowed' <<< "$out" | head -1)"
  echo "      $2: ${why:-$(grep -m1 -E 'ERROR|Message' <<< "$out" | cut -c1-120)}"
  return 1
}

app_ok() {  # app_ok REGION -> 0 if an S1 (Standard) App Service plan can be created
  local name="asp-check-$1"
  if az appservice plan create -g "$CHECK_RG" -n "$name" -l "$1" --sku S1 --is-linux false -o none 2>/dev/null; then
    az appservice plan delete -g "$CHECK_RG" -n "$name" --yes -o none
    return 0
  fi
  return 1
}

BEST_LOC="" BEST_SMALL="" BEST_BIG="" BEST_APP="no" VM_ONLY=""
seen=" "
for r in $REGIONS; do
  [[ "$seen" == *" $r "* ]] && continue; seen="$seen$r "
  echo "==> $r"
  small="" big=""
  for pair in "${PAIRS[@]}"; do
    read -r s b <<< "$pair"
    if vm_ok "$r" "$s" && vm_ok "$r" "$b"; then small="$s"; big="$b"; break; fi
  done
  if [[ -z "$small" ]]; then echo "   VMs: none of the lab sizes are available here"; continue; fi
  echo "   VMs: OK ($small, resize to $big)"
  [[ -z "$VM_ONLY" ]] && VM_ONLY="$r $small $big"
  if app_ok "$r"; then
    echo "   App Service S1: OK"
    BEST_LOC="$r" BEST_SMALL="$small" BEST_BIG="$big" BEST_APP="yes"
    break
  fi
  echo "   App Service S1: no quota here (lab 07 needs it)"
done

if [[ -z "$BEST_LOC" && -n "$VM_ONLY" ]]; then
  read -r BEST_LOC BEST_SMALL BEST_BIG <<< "$VM_ONLY"
fi
if [[ -z "$BEST_LOC" ]]; then
  echo
  echo "No checked region could run the lab VMs. Request a small quota increase (portal: Quotas >"
  echo "Compute, ask for 4 vCPUs of a B or D family in one region), then run this script again."
  exit 1
fi

cat > "$CONF" <<EOF
# Written by tools/check-region.sh on $(date -u '+%Y-%m-%d'). Delete this file to use the defaults.
# Values you set on the command line still win, e.g.  LOC=eastus2 ./deploy.sh
: "\${LOC:=$BEST_LOC}"
: "\${VM_SIZE:=$BEST_SMALL}"
: "\${VM_SIZE_BIG:=$BEST_BIG}"
EOF
echo
echo "Saved to $CONF:"
echo "   region $BEST_LOC, VM size $BEST_SMALL (lab 06 resizes to $BEST_BIG)"
[[ "$BEST_APP" == "yes" ]] || echo "   Lab 07 will need App Service quota: request 1 Standard (S1) instance in Quotas, or run it in another region."
echo "Every lab now uses these values. Run this again any time; it overwrites the file."
