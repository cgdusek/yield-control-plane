---
id: dfd-04-redemption-flow
title: Redemption Flow DFD
catalog: data-flow-catalog.yaml
trust_boundaries:
  - TB-001
  - TB-002
  - TB-003
  - TB-004
  - TB-005
last_reviewed: 2026-06-18
---

# DFD 04 Redemption Flow

This diagram shows redemption request handling, idempotency and replay behavior, modeled redemption processing, ledger and cash-credit evidence, outbox and audit events, and failure or retry behavior. The current public runtime exposes redemption request creation; the full settlement sequence is modeled by the domain transition path and tests.

```mermaid
flowchart LR
  EXT-001[External Entity: Institutional Operator]

  subgraph TB002["TB-002 Application Ingress Boundary"]
    P001(Process: API Service)
  end

  subgraph TB003["TB-003 Application Service Boundary"]
    P003(Process: Worker Services)
    P005(Process: Domain Command Handler)
  end

  subgraph TB005["TB-005 Database Financial-Record Boundary"]
    DS101[(Data Store: idempotency_records)]
    DS102[(Data Store: sweep_orders)]
    DS103[(Data Store: outbox_events)]
    DS104[(Data Store: inbox_messages)]
    DS106[(Data Store: ledger_entries)]
    DS107[(Data Store: state_transitions)]
    DS108[(Data Store: audit_events)]
  end

  subgraph TB004["TB-004 Messaging Boundary"]
    MQ002[(Queue/Topic: SQS Worker Queues)]
  end

  EXT-001 -->|DF-016: Request redemption| P001
  P001 -->|DF-003: Redemption idempotency| DS101
  P001 -->|DF-016: RequestRedemption command| P005
  P005 -->|DF-015: RedemptionRequested transition| DS107
  P005 -->|DF-005: RedemptionRequested outbox| DS103
  P005 -->|DF-015: Redemption audit event| DS108
  DS103 -->|DF-005: Redemption event for publication| MQ002
  MQ002 -->|DF-009: Redemption worker message| P003
  P003 -->|DF-010: Inbox dedupe for retry| DS104
  P003 -->|DF-017: Confirm redemption and credit cash command| P005
  P005 -->|DF-017: CashCredited order state| DS102
  P005 -->|DF-014: Ledger and cash-credit evidence| DS106
  P005 -->|DF-015: Cash-credit transition and audit| DS107
  P005 -->|DF-015: Cash-credit audit event| DS108
```
