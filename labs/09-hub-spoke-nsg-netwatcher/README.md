# Lab 09: Hub-spoke peering, NSG, and proof with Network Watcher

**Ticket INC-1009 · Priority 2 · 40 minutes · $0.02 to $0.20 per hour (2 VMs)**

> "The app servers in the new spoke network need to be managed from the hub. Only the hub may SSH in. Prove it works before we hand it over." (Network lead)

## Goal
- `vnet-hub` 10.10.0.0/16 and `vnet-spoke1` 10.20.0.0/16, peered **both ways**.
- NSG on `snet-app`: allow TCP 22 from 10.10.0.0/16 (priority 100), deny TCP 22 from VirtualNetwork (priority 200).
- Prove with **IP flow verify**, **next hop**, and a real ping.

## Steps
1. `./deploy.sh`
2. `./verify.sh`
3. Break it on purpose and fix it:
   - Swap the priorities and rerun IP flow verify. Two rules in one NSG cannot share a priority, so use a temporary number:
     `az network nsg rule update -g rg-az104-lab09 --nsg-name nsg-snet-app -n allow-ssh-from-hub --priority 150`
     then set `deny-ssh-other` to 100 and `allow-ssh-from-hub` to 200. The deny rule now wins.
   - IP flow verify names the matching rule: your own rules show as `securityRules/allow-ssh-from-hub`, default rules as `defaultSecurityRules/...`.
   - Delete one side of the peering, for example `az network vnet peering delete -g rg-az104-lab09 --vnet-name vnet-spoke1 -n spoke1-to-hub`. The other side goes to Disconnected and ping fails.
4. Fix it, then prove it is fixed. Hints first, full commands below if you are stuck:
   - Hint 1: which rule should win, and which number must it have?
   - Hint 2: a peering left Disconnected cannot be reconnected. Recreating only the side you deleted fails with `RemotePeeringIsDisconnected`.
   - Fix (priorities, in this order because two rules cannot share a number):
     ```bash
     az network nsg rule update -g rg-az104-lab09 --nsg-name nsg-snet-app -n allow-ssh-from-hub --priority 150
     az network nsg rule update -g rg-az104-lab09 --nsg-name nsg-snet-app -n deny-ssh-other --priority 200
     az network nsg rule update -g rg-az104-lab09 --nsg-name nsg-snet-app -n allow-ssh-from-hub --priority 100
     ```
   - Fix (peering): delete the Disconnected side, then create both sides again:
     ```bash
     az network vnet peering delete -g rg-az104-lab09 --vnet-name vnet-hub -n hub-to-spoke1
     az network vnet peering create -g rg-az104-lab09 -n hub-to-spoke1 --vnet-name vnet-hub \
       --remote-vnet vnet-spoke1 --allow-vnet-access --allow-forwarded-traffic
     az network vnet peering create -g rg-az104-lab09 -n spoke1-to-hub --vnet-name vnet-spoke1 \
       --remote-vnet vnet-hub --allow-vnet-access --allow-forwarded-traffic
     ```
   - Done when `./verify.sh` shows PASS again, both peerings show Connected, and you can say in one sentence what broke and why. Fix it by hand as above; do not rely on rerunning `./deploy.sh` to undo a deliberate change.

## Rules to remember
- Address spaces of peered VNets **must not overlap**.
- A peering left **Disconnected** (because the other side was deleted) cannot be reconnected: delete it and create both sides again.
- Peering is **not transitive**: spoke1 cannot reach spoke2 through the hub unless you add routing (an NVA or firewall with UDRs, or gateway transit for VPN traffic).
- NSG rules are processed by **priority, lowest number first**, and stop at the first match.
- Ping is ICMP. The default rule *AllowVnetInBound* allows it inside the VNet and across peering.

## Explain it (interview)
"I never guess with network issues. IP flow verify tells me which NSG rule allows or denies a 5-tuple. Next hop tells me where the packet goes. Effective security rules on the NIC show the combined subnet and NIC rules."

## Cleanup
`./cleanup.sh`
