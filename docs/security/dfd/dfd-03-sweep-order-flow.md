---
id: dfd-03-sweep-order-flow
title: Sweep Order Flow DFD
catalog: data-flow-catalog.yaml
trust_boundaries:
  - TB-001
  - TB-002
  - TB-003
  - TB-004
  - TB-005
  - TB-009
last_reviewed: 2026-06-18
---

# DFD 03 Sweep Order Flow

This diagram shows the detailed sweep order path from request through persistence, outbox, SNS/SQS, worker dedupe, mock transfer-agent confirmation, position booking, ledger entries, reconciliation, and audit evidence.

```mermaid
flowchart LR
  EXT-001[External Entity: Institutional Operator]
  EXT-002[External Entity: Mock Transfer Agent]

  subgraph TB002["TB-002 Application Ingress Boundary"]
    P001(Process: API Service)
  end

  subgraph TB003["TB-003 Application Service Boundary"]
    P002(Process: Outbox Publisher)
    P003(Process: Worker Services)
    P005(Process: Domain Command Handler)
  end

  subgraph TB005["TB-005 Database Financial-Record Boundary"]
    DS101[(Data Store: idempotency_records)]
    DS102[(Data Store: sweep_orders)]
    DS103[(Data Store: outbox_events)]
    DS104[(Data Store: inbox_messages)]
    DS105[(Data Store: positions)]
    DS106[(Data Store: ledger_entries)]
    DS107[(Data Store: state_transitions)]
    DS108[(Data Store: audit_events)]
  end

  subgraph TB004["TB-004 Messaging Boundary"]
    MQ001[(Queue/Topic: SNS Domain Events)]
    MQ002[(Queue/Topic: SQS Worker Queues)]
  end

  EXT-001 -->|DF-002: Create sweep order| P001
  P001 -->|DF-003: Idempotency record| DS101
  P001 -->|DF-004: Created order| DS102
  P001 -->|DF-005: SweepOrderCreated outbox| DS103
  P001 -->|DF-015: Created transition and audit| DS107
  P001 -->|DF-015: Created audit event| DS108
  DS103 -->|DF-006: Lease pending event| P002
  P002 -->|DF-007: Publish EventEnvelope| MQ001
  MQ001 -->|DF-008: Fanout event to queues| MQ002
  MQ002 -->|DF-009: Worker receives event| P003
  P003 -->|DF-010: Inbox dedupe| DS104
  P003 -->|DF-011: Subscription request| EXT-002
  EXT-002 -->|DF-011: Confirmation response| P003
  P003 -->|DF-012: Confirm and book commands| P005
  P005 -->|DF-012: Position record| DS105
  P005 -->|DF-014: Cash lock and position ledger| DS106
  P005 -->|DF-015: Lifecycle transitions| DS107
  P005 -->|DF-015: Lifecycle audit events| DS108
  P003 -->|DF-013: Reconciliation commands| P005
  P005 -->|DF-013: Reconciled and Active order| DS102
```
