#!/usr/bin/env bash
# One-time setup for a NEW subscription, before the labs:
#   1. registers the resource providers the labs use (new subscriptions start with few registered)
#   2. creates a monthly budget of 20 (in your billing currency) with email alerts at 50, 80 and 100%
#   3. shows your vCPU quota for the lab region
# Then run tools/check-region.sh before the first VM lab.
# Usage: EMAIL=you@example.com bash tools/setup-subscription.sh
set -uo pipefail
EMAIL="${EMAIL:-}"
LOC="${LOC:-canadacentral}"
[[ -n "$EMAIL" ]] || { echo "Usage: EMAIL=you@example.com bash tools/setup-subscription.sh"; exit 1; }
SUB="$(az account show --query id -o tsv)" || { echo "Not signed in. Run az login."; exit 1; }
echo "Subscription: $(az account show --query name -o tsv) ($SUB)"

echo "1. Registering resource providers"
for p in Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.Web \
         Microsoft.ContainerInstance Microsoft.App Microsoft.ContainerRegistry \
         Microsoft.OperationalInsights Microsoft.Insights Microsoft.AlertsManagement \
         Microsoft.RecoveryServices Microsoft.DataProtection Microsoft.PolicyInsights \
         Microsoft.KeyVault Microsoft.ManagedIdentity Microsoft.CloudShell \
         Microsoft.CostManagement Microsoft.Consumption; do
  az provider register --namespace "$p" -o none && echo "   $p"
done

# Budgets need Microsoft.Consumption registered first (a brand-new subscription may not have it yet).
az provider register --namespace Microsoft.Consumption --wait -o none
echo "2. Budget lab-budget (20 per month, alerts at 50/80/100% to $EMAIL)"
S="$(date +%Y-%m-01)"
E="$(date -d '+1 year' +%Y-%m-01)"
notif() { printf '"at%s":{"enabled":true,"operator":"GreaterThan","threshold":%s,"contactEmails":["%s"]}' "$1" "$1" "$EMAIL"; }
BODY="{\"properties\":{\"category\":\"Cost\",\"amount\":20,\"timeGrain\":\"Monthly\",\"timePeriod\":{\"startDate\":\"${S}T00:00:00Z\",\"endDate\":\"${E}T00:00:00Z\"},\"notifications\":{$(notif 50),$(notif 80),$(notif 100)}}}"
if az rest --method put \
     --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Consumption/budgets/lab-budget?api-version=2023-05-01" \
     --body "$BODY" -o none; then
  echo "   Budget created."
else
  echo "   Could not create the budget from the CLI. Create it in the portal: Cost Management > Budgets > Add."
fi

echo "3. Waiting for provider registration (can take a few minutes)"
for _ in $(seq 1 30); do
  pending="$(az provider list --query "[?registrationState=='Registering'] | length(@)" -o tsv)"
  [[ "$pending" == "0" ]] && break
  echo "   still registering: $pending"
  sleep 20
done

echo "4. vCPU quota in $LOC (labs need about 2 to 4 vCPUs at a time)"
az vm list-usage --location "$LOC" -o table | grep -iE "Total Regional vCPUs|Basv2|BSv2|DALSv6|DASv6|DASv5" || true
echo "Setup finished. Next: bash tools/check-region.sh  (finds a region and VM size your subscription can use)"
