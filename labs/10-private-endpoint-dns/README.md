# Lab 10: Private endpoint and private DNS for storage

**Ticket SEC-3010 · Priority 1 · 40 minutes · about $0.05 per hour**

> "Security audit finding: the HR storage account is reachable from the internet. Make it private to our network only, without breaking the app." (Security team)

## Goal
- Storage account with **public network access disabled**.
- **Private endpoint** for the `blob` sub-resource in `snet-pe`.
- **Private DNS zone** `privatelink.blob.core.windows.net`, linked to the VNet, with the A record created by a DNS zone group.
- Prove: inside the VNet the name resolves to a 10.60.2.x address; from the internet the request is refused.

## Steps
1. `./deploy.sh`
2. `./verify.sh`

## Service endpoint vs private endpoint
| | Service endpoint | Private endpoint |
|---|---|---|
| Traffic goes to | The service's **public** IP, over the Azure backbone | A **private IP** in your subnet |
| Reachable from on-premises (VPN/ExpressRoute) | No | Yes |
| DNS changes needed | No | Yes (privatelink zone) |
| Granularity | Whole service type in the region | One specific resource (one account, one sub-resource) |
| Cost | Free | Per hour + per GB |

## Explain it (interview)
"The app connects to the same name, mystorage.blob.core.windows.net. Inside the VNet, private DNS answers with the private endpoint's IP, so traffic never leaves our network. Most private endpoint tickets are really DNS tickets: check what the name resolves to first."

## Cleanup
`./cleanup.sh`
