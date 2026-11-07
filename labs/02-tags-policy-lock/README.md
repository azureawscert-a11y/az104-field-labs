# Lab 02: Enforce tags and stop accidental deletes

**Ticket INC-1002 · Priority 2 · 30 minutes · Free**

> "Finance can't split the Azure bill because half our resources have no cost center. Also, someone almost deleted the payroll resource group last week." (IT manager)

## Goal
- Assign the built-in policy **Require a tag on resources** at the resource group scope with `tagName = CostCenter` (effect: Deny).
- Add a **CanNotDelete** lock to the resource group.
- Prove both work.

## Steps
1. `./deploy.sh`
2. Wait 5 to 30 minutes (policy assignments are not instant).
3. `./verify.sh` tries to create an untagged storage account (should be denied), a tagged one (should succeed), and to delete the tagged one (should be blocked by the lock).

## Explain it (interview)
"RBAC decides **who** can act. Policy decides **what** is allowed, even for an Owner. A lock stops deletes or changes even when RBAC and Policy allow them. Locks are inherited by everything in the group, so the lock had to come off before cleanup."

## Note
This policy does not look at the resource group's own tags, only resources inside it. To copy the group's tag onto resources automatically, look at the built-in policy *Inherit a tag from the resource group if missing* (Modify effect, needs a remediation task for existing resources).

## Cleanup
`./cleanup.sh` removes the lock first, then the policy assignment and the group.
