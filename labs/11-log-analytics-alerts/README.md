# Lab 11: Logs, KQL and alerts

**Ticket OPS-4011 · Priority 2 · 40 minutes · under $0.05**

> "Something keeps hammering the documents storage account and nobody notices until the bill arrives. I want an email when it gets busy, and a way to see who is doing what. But not on weekends." (Cloud ops lead)

## Goal
- **Log Analytics workspace** with 30-day retention.
- **Diagnostic setting** on the storage account's blob service: StorageRead, StorageWrite, StorageDelete logs plus Transaction metrics.
- **Action group** that emails you.
- **Metric alert** on Transactions > 50 in 5 minutes.
- **Alert processing rule** that removes notifications on weekends (Eastern time). If you run the lab on a Saturday or Sunday, no email arrives (a brand-new rule can take a few minutes to apply, so one email may slip through): the alert still fires, and you can see it in **Monitor > Alerts**.
- Five **KQL** queries in `queries.kql`.

## Steps
1. `EMAIL=you@example.com ./deploy.sh` (confirm the action group email that Azure sends you)
2. Wait 10 to 15 minutes. Run the queries in the portal (workspace > Logs).
3. `./verify.sh`

## Metrics vs logs
| | Metrics | Logs |
|---|---|---|
| What | Numbers over time (CPU %, transactions) | Detailed records (who, what, when, result) |
| Collected | Automatically for platform metrics | Only after you create a diagnostic setting |
| Speed | Near real time | Minutes |
| Query with | Metrics explorer | KQL in Log Analytics |

## Explain it (interview)
"Platform metrics are there by default, but resource logs are not: I had to add a diagnostic setting to send them to Log Analytics. Alert rules decide **when**, action groups decide **who and how**, and alert processing rules change that at scale, for example silence during maintenance."

## Cleanup
`./cleanup.sh`
