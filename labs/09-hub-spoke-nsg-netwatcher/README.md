# Lab 09: Hub-spoke peering, NSG, and proof with Network Watcher

**Ticket INC-1009 · Priority 2 · 40 minutes · about $0.05 per hour**

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
   - IP flow verify names the matching rule with a prefix: custom rules show as `UserRule_allow-ssh-from-hub`, default rules as `DefaultRule_...`.
   - Delete one side of the peering. Peering state goes to Disconnected and ping fails.

## Rules to remember
- Address spaces of peered VNets **must not overlap**.
- Peering is **not transitive**: spoke1 cannot reach spoke2 through the hub unless you add routing (an NVA or firewall with UDRs, or gateway transit for VPN traffic).
- NSG rules are processed by **priority, lowest number first**, and stop at the first match.
- Ping is ICMP. The default rule *AllowVnetInBound* allows it inside the VNet and across peering.

## Explain it (interview)
"I never guess with network issues. IP flow verify tells me which NSG rule allows or denies a 5-tuple. Next hop tells me where the packet goes. Effective security rules on the NIC show the combined subnet and NIC rules."

## Cleanup
`./cleanup.sh`
