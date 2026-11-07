# Lab 01: Onboard a new hire

**Ticket INC-1001 · Priority 3 · 20 minutes · Free**

> "Priya starts Monday in Finance. She needs to see the finance resources in Azure but must not change anything." (Finance manager)

## Goal
Create the user, put her in a security group, and give the **group** the **Reader** role on the resource group `rg-az104-lab01`. Access through groups, never directly to people.

## Steps
1. `./deploy.sh` creates the resource group, the user (with a random temporary password and forced change at first sign-in), the group `grp-finance-readers`, adds her, and assigns Reader to the group at resource group scope.
2. Sign in as the new user in a private browser window (portal.azure.com) and confirm she can open the resource group but cannot create anything inside it.
3. `./verify.sh`

## Verify
- User exists and is a member of the group.
- The group has exactly one Reader assignment on the resource group.
- The user has no direct assignment.

## Explain it (interview)
"I used a group and assigned Reader at the resource group scope, the smallest scope that covers what she needs. When she leaves or changes teams, I remove her from one group instead of hunting for role assignments."

## Cleanup
`./cleanup.sh` removes the assignment, the user, the group and the resource group.
