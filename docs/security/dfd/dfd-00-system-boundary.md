---
id: dfd-00-system-boundary
title: System Boundary DFD
catalog: data-flow-catalog.yaml
trust_boundaries:
  - TB-001
  - TB-002
  - TB-003
  - TB-004
  - TB-005
  - TB-006
  - TB-007
  - TB-008
  - TB-009
last_reviewed: 2026-06-18
---

# DFD 00 System Boundary

This diagram shows the major external actors, runtime systems, data stores, queues, AWS sandbox services, CI/CD, and evidence outputs. Flow details and controls are defined in [data-flow-catalog.yaml](data-flow-catalog.yaml) and [control-map.yaml](control-map.yaml).

```mermaid
flowchart LR
  EXT-001[External Entity: Institutional Operator]
  EXT-002[External Entity: Mock Transfer Agent]
  EXT-003[External Entity: CI/CD Runner]

  subgraph TB001["TB-001 Public Internet / External User Boundary"]
    P006(Process: React Console)
  end

  subgraph TB002["TB-002 Application Ingress Boundary"]
    P001(Process: API Service)
  end

  subgraph TB003["TB-003 Application Service Boundary"]
    P002(Process: Outbox Publisher)
    P003(Process: Worker Services)
    P007(Process: Certifier Service)
  end

  subgraph TB004["TB-004 Messaging Boundary"]
    MQ001[(Queue/Topic: SNS Domain Events)]
    MQ002[(Queue/Topic: SQS Worker Queues)]
  end

  subgraph TB005["TB-005 Database Financial-Record Boundary"]
    DS001[(Data Store: Postgres Financial Store)]
  end

  subgraph TB006["TB-006 AWS Account / Cloud Control-Plane Boundary"]
    P008(Process: AWS Certification Scripts)
    P010(Process: AWS FIS Experiment)
    DS003[(Data Store: AWS Secrets Manager)]
    DS005[(Data Store: CloudWatch Logs)]
  end

  subgraph TB007["TB-007 CI/CD and Source-Control Boundary"]
    P009(Process: Validation Gate)
  end

  subgraph TB008["TB-008 Evidence Artifact Boundary"]
    DS004[(Data Store: Evidence Artifacts)]
  end

  EXT-001 -->|DF-001: Sweep policy intent| P006
  P006 -->|DF-001: Create sweep policy| P001
  EXT-001 -->|DF-002: Create sweep order| P001
  EXT-001 -->|DF-016: Request redemption| P001
  EXT-001 -->|DF-018: Toggle mismatch injection| P001
  P001 -->|DF-003: Idempotency record| DS001
  P001 -->|DF-004: Sweep order record| DS001
  P001 -->|DF-005: Outbox and audit event| DS001
  DS001 -->|DF-006: Pending event lease| P002
  P002 -->|DF-007: Domain event publish| MQ001
  MQ001 -->|DF-008: Worker fanout| MQ002
  MQ002 -->|DF-009: Worker message| P003
  P003 -->|DF-011: Subscription request| EXT-002
  P003 -->|DF-012: Confirmation and position| DS001
  P003 -->|DF-013: Reconciliation result| DS001
  P007 -->|DF-019: DB invariant report| DS004
  P008 -->|DF-020: AWS evidence collection| DS004
  EXT-003 -->|DF-021: Validation run| P009
  P010 -->|DF-022: Stop worker task| P003
  DS003 -->|DF-024: Database URL secret| P001
  P003 -->|DF-025: Service logs| DS005
```
