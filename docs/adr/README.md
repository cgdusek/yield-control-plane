# Architecture Decision Records

ADRs record material choices that affect runtime behavior, safety invariants, local operability, or production-shaped boundaries.

Status legend:

- Proposed: written but not yet enforced by code or validation.
- Accepted: enforced by code, scripts, tests, docs, or CI.
- Superseded: replaced by a later ADR.

Template:

```markdown
# ADR-NNNN: Title

## Status
Proposed / Accepted / Superseded

## Context
What problem or constraint led to this decision?

## Decision
What is the decision?

## Options Considered
- Option A
- Option B
- Option C

## Rationale
Why this option?

## Consequences
Positive and negative consequences.

## Validation
How this decision is validated by tests, scripts, docs, or runtime behavior.
```

## Index

- [ADR-0001: Use a Rust Workspace and Shared Domain Crates](0001-use-rust-workspace-and-shared-domain-crates.md)
- [ADR-0002: Use LocalStack for Local SNS/SQS](0002-use-localstack-for-local-sns-sqs.md)
- [ADR-0003: Use Postgres, SQLx, and an Append-Only Ledger](0003-use-postgres-sqlx-and-append-only-ledger.md)
- [ADR-0004: Enforce the State Machine in the Domain Layer](0004-enforce-state-machine-in-domain-layer.md)
- [ADR-0005: Use Outbox, Inbox, and Idempotency for Resilient Messaging](0005-use-outbox-inbox-for-resilient-messaging.md)
- [ADR-0006: Use React TypeScript with a Contract-Aligned API Client](0006-use-react-typescript-generated-api-client.md)
- [ADR-0007: Use Docker Compose for the Primary Local Runtime](0007-use-docker-compose-for-primary-local-runtime.md)
- [ADR-0008: Provide kind Kubernetes Bootstrap](0008-provide-kind-kubernetes-bootstrap.md)
- [ADR-0009: Use Local Mock Transfer Agent and Chain Watcher](0009-use-mock-transfer-agent-and-chain-observer-locally.md)
- [ADR-0010: Block Real AWS Calls in Local Mode](0010-no-real-aws-calls-in-local-mode.md)
- [ADR-0011: Document How Production AWS Differs from Local Simulation](0011-production-aws-differs-from-local-simulation.md)
- [ADR-0012: Enforce Financial Safety Invariants in Domain and Persistence](0012-enforce-financial-safety-invariants.md)
