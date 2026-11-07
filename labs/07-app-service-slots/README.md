# Lab 07: Zero-downtime release with a slot swap

**Ticket CHG-2007 · Priority 2 · 30 minutes · about $0.10 per hour (S1)**

> "Last release took the site down for 10 minutes. Can we test the new version on the real platform first and switch over instantly?" (Product owner)

## Goal
- App Service plan **S1** and a web app with HTTPS only.
- Version 1 in production, Version 2 in a **staging** slot.
- A **slot setting** (`ENVIRONMENT`) that stays with its slot.
- Swap staging into production, then prove rollback is one more swap.

## Steps
1. `./deploy.sh`
2. Open both URLs the script prints.
3. Swap: `az webapp deployment slot swap --name <app> --resource-group rg-az104-lab07 --slot staging --target-slot production`
4. `./verify.sh`

## Things to know
- Slots need **Standard, Premium or Isolated** tiers. Free/Basic cannot have them.
- A swap warms up the staging instances before switching traffic, so users see no cold start.
- Settings marked as **slot settings** (sticky) do not move. Everything else swaps with the code.
- Scale out (more instances) vs scale up (bigger tier): configure scale out under the plan, manually or with autoscale rules (Standard and higher).

## Explain it (interview)
"We deploy to staging, smoke-test it on the real platform, then swap. If something breaks, we swap back in seconds. Connection strings that must never cross environments are slot settings."

## Cleanup
`./cleanup.sh`
