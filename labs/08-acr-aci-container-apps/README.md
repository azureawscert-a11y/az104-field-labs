# Lab 08: From private registry to running container

**Ticket CHG-2008 · Priority 3 · 35 minutes · under $0.20**

> "The dev team built a container image. Put it in our own registry and get it running. One copy for a quick demo, and one that can scale when marketing launches." (Dev lead)

## Goal
- **Azure Container Registry** (Basic) with the image `hello:v1` imported from Microsoft's public registry.
- Run it on **Azure Container Instances** (1 vCPU, 1.5 GiB, public DNS name).
- Run it on **Azure Container Apps** with external HTTPS ingress, then change scaling to min 1, max 5, HTTP rule at 20 concurrent requests.

## Steps
1. `./deploy.sh`
2. Open both URLs.
3. `./verify.sh`

## ACI vs Container Apps
| | ACI | Container Apps |
|---|---|---|
| Best for | One-off jobs, quick demos, simple tasks | Web APIs, microservices, event-driven apps |
| Scaling | Fixed: you choose CPU/memory per container group | Replicas scale on HTTP, CPU, queues (KEDA), down to zero |
| HTTPS ingress | No built-in TLS | Built in, with a managed FQDN |
| Size change | Recreate the container group | Update the app, new revision |

## Explain it (interview)
"Images live in our private registry, not Docker Hub. ACI is fine for a short task. For the real app I used Container Apps because it scales on traffic and gives HTTPS out of the box. In production I'd use a managed identity with AcrPull instead of the admin user."

## Cleanup
`./cleanup.sh`
