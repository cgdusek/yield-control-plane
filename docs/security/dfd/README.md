---
id: dfd-evidence-pack
title: Data-Flow Diagram Evidence Pack
source_of_truth:
  - data-flow-catalog.yaml
  - data-classification.yaml
  - trust-boundaries.yaml
  - control-map.yaml
last_reviewed: 2026-06-18
---

# Data-Flow Diagram Evidence Pack

## Purpose

This pack documents Yield Control Plane data flows for security, AWS sandbox, financial-control, and SOC 2 readiness review. Mermaid diagrams are the visual view. YAML files are the structured source of truth.

## Scope

The scope is the existing local runtime, Rust services, Postgres records, LocalStack SNS/SQS flow, React console, mock transfer agent, non-production AWS sandbox simulation, validation gates, and evidence artifacts.

## Non-Claims

This pack does not create SOC attestation, AWS assurance, regulatory approval, legal advice, investment advice, tax advice, accounting advice, transfer-agent authorization, customer-data authorization, production authorization, or production readiness.

## DFD Legend

| Type | ID Pattern | Mermaid Convention |
| --- | --- | --- |
| External entity | `EXT-###` | `EXT-001[External Entity: Name]` |
| Process | `P-###` | `P001(Process: Name)` |
| Data store | `DS-###` | `DS001[(Data Store: Name)]` |
| Queue or topic | `MQ-###` | `MQ001[(Queue/Topic: Name)]` |
| Trust boundary | `TB-###` | Mermaid `subgraph` labeled with boundary ID |
| Data flow | `DF-###` | Arrow label includes ID and short data name |
| Control | `CTL-...` | Control IDs live in `control-map.yaml` |

## Data Classification Summary

The classification source is [data-classification.yaml](data-classification.yaml). The pack defines `public`, `internal`, `confidential`, `restricted_financial_record`, `restricted_secret`, `restricted_audit_evidence`, and `pii_if_enabled`.

Restricted financial records cover order, ledger, position, reconciliation, outbox, inbox, and audit-event data. Restricted secrets cover database URLs, passwords, keys, and temporary AWS material. Restricted audit evidence covers generated campaign artifacts and reviewer evidence.

## Trust Boundary Summary

The boundary source is [trust-boundaries.yaml](trust-boundaries.yaml). The modeled boundaries are public ingress, application ingress, application service internals, messaging, database financial records, AWS account and cloud control plane, CI/CD and source control, evidence artifacts, and transfer-agent integration.

## Diagram Index

- [DFD 00 System Boundary](dfd-00-system-boundary.md)
- [DFD 01 Logical Runtime](dfd-01-logical-runtime.md)
- [DFD 02 AWS Sandbox](dfd-02-aws-certification-sandbox.md)
- [DFD 03 Sweep Order Flow](dfd-03-sweep-order-flow.md)
- [DFD 04 Redemption Flow](dfd-04-redemption-flow.md)
- [DFD 05 Reconciliation Exception Flow](dfd-05-reconciliation-exception-flow.md)

## How To Validate The DFD Pack

Run the dedicated DFD gate:

```bash
make validate-dfd
```

The validator checks required files, YAML syntax, diagram-to-catalog `DF-###` references, source-file references, control references, classification coverage, boundary mapping, restricted-data fields, marker text, and unsupported external-assurance wording.

## SOC 2 Readiness Support

This pack supports readiness review for:

- Security: trust boundaries, transport expectations, local and AWS sandbox guardrails, secrets handling, KMS-backed sandbox services, and least-privilege evidence.
- Availability: SQS retries, DLQs, queue-drain evidence, ECS replacement checks, and FIS worker-stop evidence in the sandbox.
- Processing Integrity: idempotency, domain transition enforcement, state-transition audit trail, ledger balancing, append-only ledger trigger, and DB invariant reporting.
- Confidentiality: data classification, restricted financial records, restricted audit evidence, Secrets Manager, KMS encryption, and private evidence handling.
- Privacy: current no-customer-data boundary plus future `pii_if_enabled` classification and owner controls.
