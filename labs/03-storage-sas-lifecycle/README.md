# Lab 03: Share files with a partner, safely

**Ticket INC-1003 · Priority 3 · 25 minutes · < $0.05**

> "Our auditor needs read access to the quarterly reports for one month. No Azure account for them. And we need to be able to cut access off instantly." (Controller)

## Goal
- Storage account with public blob access **disabled**, TLS 1.2, HTTPS only.
- Private container `partner-share` with a sample report.
- A **stored access policy** (read + list, 30 days) and a **service SAS** that references it.
- **Lifecycle management**: move reports to Cool after 30 days, Archive after 90, delete after 365.
- Prove the SAS can be revoked without rotating the account key.

## Steps
1. `./deploy.sh` (creates `sas.txt` with the partner link, do not commit it)
2. `./verify.sh` downloads with the SAS and shows it fails without it. Safe to run again.
3. `./revoke.sh` deletes the stored access policy and shows the same link now returns 403. Run `./deploy.sh` again if you want the link back.

## Explain it (interview)
"An ad hoc service SAS signed with an account key can only be revoked by rotating that key, which breaks every other app using it. A SAS tied to a stored access policy can be revoked by deleting or changing the policy. A user delegation SAS (signed with Entra ID credentials) is the most secure option for blobs."

## Cleanup
`./cleanup.sh`
