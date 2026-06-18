---
id: dfd-05-reconciliation-exception-flow
title: Reconciliation Exception Flow DFD
catalog: data-flow-catalog.yaml
trust_boundaries:
  - TB-001
  - TB-002
  - TB-003
  - TB-004
  - TB-005
  - TB-006
  - TB-008
last_reviewed: 2026-06-18
---

# DFD 05 Reconciliation Exception Flow

This diagram shows test-mode reconciliation mismatch injection, reconciliation worker behavior, exception opening, audit events, queue-drain evidence, and operator or evidence review paths.

```mermaid
flowchart LR
  EXT-001[External Entity: Institutional Operator]

  subgraph TB002["TB-002 Application Ingress Boundary"]
    P001(Process: API Service)
  end

  subgraph TB003["TB-003 Application Service Boundary"]
    P003(Process: Reconciliation Worker)
    P005(Process: Domain Command Handler)
  end

  subgraph TB005["TB-005 Database Financial-Record Boundary"]
    DS110[(Data Store: failure_injections)]
    DS104[(Data Store: inbox_messages)]
    DS102[(Data Store: sweep_orders)]
    DS107[(Data Store: state_transitions)]
    DS108[(Data Store: audit_events)]
    DS109[(Data Store: reconciliation_breaks)]
  end

  subgraph TB004["TB-004 Messaging Boundary"]
    MQ002[(Queue/Topic: SQS Worker Queues)]
    MQ003[(Queue/Topic: SQS Dead-Letter Queues)]
  end

  subgraph TB006["TB-006 AWS Account / Cloud Control-Plane Boundary"]
    P008(Process: AWS Certification Scripts)
  end

  subgraph TB008["TB-008 Evidence Artifact Boundary"]
    DS004[(Data Store: Evidence Artifacts)]
  end

  EXT-001 -->|DF-018: Enable mismatch injection| P001
  P001 -->|DF-018: Store injection flag| DS110
  MQ002 -->|DF-009: PositionBooked message| P003
  P003 -->|DF-010: Inbox dedupe before handling| DS104
  P003 -->|DF-013: Read mismatch and reconcile| P005
  DS110 -->|DF-018: Current injection value| P003
  P005 -->|DF-013: ExceptionOpen order state| DS102
  P005 -->|DF-013: Reconciliation break| DS109
  P005 -->|DF-015: Exception transition| DS107
  P005 -->|DF-015: ReconciliationBreakOpened audit| DS108
  P008 -->|DF-023: Inspect source queue depth| MQ002
  P008 -->|DF-023: Inspect DLQ depth| MQ003
  P008 -->|DF-020: Collect exception evidence| DS004
  EXT-001 -->|DF-018: Disable mismatch injection| P001
```
