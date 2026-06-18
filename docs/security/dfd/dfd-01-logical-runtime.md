---
id: dfd-01-logical-runtime
title: Logical Runtime DFD
catalog: data-flow-catalog.yaml
trust_boundaries:
  - TB-003
  - TB-004
  - TB-005
last_reviewed: 2026-06-18
---

# DFD 01 Logical Runtime

This diagram shows the logical runtime flow from API persistence through outbox publication, queue fanout, worker processing, positions, ledger entries, audit events, and reconciliation.

```mermaid
flowchart LR
  subgraph TB003["TB-003 Application Service Boundary"]
    P001(Process: API Service)
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
    DS109[(Data Store: reconciliation_breaks)]
  end

  subgraph TB004["TB-004 Messaging Boundary"]
    MQ001[(Queue/Topic: SNS Domain Events)]
    MQ002[(Queue/Topic: SQS Worker Queues)]
  end

  P001 -->|DF-003: Idempotency record| DS101
  P001 -->|DF-004: Sweep order row| DS102
  P001 -->|DF-005: Outbox event| DS103
  P001 -->|DF-005: Audit event| DS108
  DS103 -->|DF-006: Pending event lease| P002
  P002 -->|DF-007: Event envelope publish| MQ001
  MQ001 -->|DF-008: Raw event fanout| MQ002
  MQ002 -->|DF-009: Worker receives message| P003
  P003 -->|DF-010: Inbox dedupe record| DS104
  P003 -->|DF-012: Confirm and book position| P005
  P003 -->|DF-013: Reconcile or open break| P005
  P005 -->|DF-012: Position record| DS105
  P005 -->|DF-014: Balanced ledger entries| DS106
  P005 -->|DF-015: State transition| DS107
  P005 -->|DF-015: Audit trail event| DS108
  P005 -->|DF-013: Reconciliation break| DS109
  P005 -->|DF-017: Redemption cash credit transition| DS102
```
