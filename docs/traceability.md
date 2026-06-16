# Requirements Traceability

Source of truth: [spec/source/fidelity_defi_yield_platform_spec.md](../spec/source/fidelity_defi_yield_platform_spec.md)

This document maps the source requirements into repository artifacts. The tracker is authoritative for current gate status; this document records the intended disposition and final evidence locations. A row is not considered complete until `AGENT_TRACKER.md` records a passing gate or a bounded deferral.

Target disposition values:

- Implemented now: executable in the local project.
- Implemented as local mock: behavior is present with local-only simulation boundaries.
- Documented production pattern: architecture or operations are documented, but no real cloud integration is performed.
- Deferred with reason: intentionally not executed locally, with rationale.

| Requirement | Target Disposition | Evidence Artifacts |
| --- | --- | --- |
| Rust workspace with shared crates and deployable services | Implemented now | `Cargo.toml`, `crates/*`, `services/*`, `.github/workflows/ci.yml` |
| Axum HTTP API | Implemented now | `services/api`, `spec/openapi.yaml`, API tests |
| Tokio async runtime | Implemented now | Service binaries and messaging workers |
| Postgres durable financial state | Implemented now | `crates/persistence/migrations`, `docker-compose.yml` |
| SQLx migrations | Implemented now | `crates/persistence/migrations`, `scripts/dev-up.sh`, CI migration gate |
| LocalStack SNS/SQS fanout | Implemented as local mock | `crates/messaging`, `scripts/localstack-init.sh`, `docker-compose.yml` |
| SQS workers with retries, idempotency, DLQ, graceful shutdown | Implemented now | `services/worker`, `crates/persistence/src/inbox.rs`, runbooks |
| Sweep order state machine | Implemented now | `spec/domain/sweep_order.machine.yaml`, `crates/domain/src/sweep.rs`, tests |
| OpenAPI REST contract | Implemented now | `spec/openapi.yaml`, `scripts/validate-specs.sh` |
| AsyncAPI event contract | Implemented now | `spec/asyncapi.yaml`, `scripts/validate-specs.sh` |
| JSON Schema event payloads | Implemented now | `spec/schemas/events/*.json`, `scripts/validate-specs.sh` |
| React/TypeScript frontend | Implemented now | `web/react-console`, frontend tests |
| Docker Compose local runtime | Implemented now | `docker-compose.yml`, `scripts/dev-up.sh`, `scripts/dev-down.sh`, `scripts/dev-reset.sh` |
| Kubernetes local bootstrap | Implemented now | `infra/k8s/base`, `infra/k8s/overlays/local`, `infra/k8s/kind`, `scripts/smoke-k8s.sh` |
| Agentic docs system | Implemented now | `AGENTS.md`, `AGENT_TRACKER.md`, `docs/agentic/*` |
| ADR-backed decisions | Implemented now | `docs/adr/*.md` |
| Unit, property, integration, contract, frontend, smoke tests | Implemented now | Rust tests, `scripts/validate-specs.sh`, `web/react-console`, smoke scripts |
| CI pipeline matching local gates | Implemented now | `.github/workflows/ci.yml`, `scripts/validate-all.sh` |
| Happy path from UI/API to Active order | Implemented now | API, workers, outbox, LocalStack, smoke script |
| Duplicate idempotency key creates no duplicate order | Implemented now | DB unique index, API idempotency handler, domain/persistence tests, smoke script |
| Duplicate external confirmation creates no duplicate position | Implemented now | DB unique index, worker idempotency, tests, smoke script |
| Reconciliation mismatch opens break | Implemented now | Reconciliation worker, `reconciliation_breaks` table, smoke script |
| FIDD balance does not itself earn yield | Implemented now | Domain invariant, API rejection path, UI copy, tests |
| Direct status mutation forbidden | Implemented now | Domain transition API, repository command handlers, docs, tests |
| Financial writes idempotent | Implemented now | `idempotency_records`, unique indexes, command handlers |
| Workers safe under at-least-once delivery | Implemented now | Inbox deduplication, unique constraints, idempotent mock transfer agent |
| No real AWS calls in local mode | Implemented now | Config defaults, LocalStack endpoint checks, ADR-0010, docs/security.md |
| No secrets or private keys committed | Implemented now | `.env.example`, `.gitignore`, docs/security.md |
| Production AWS/EKS/IAM differences documented | Documented production pattern | `docs/production-readiness.md`, `infra/k8s/overlays/aws-shaped`, ADR-0011 |
| Legal/investment/accounting/tax/regulatory non-claims | Documented production pattern | `README.md`, `docs/security.md`, UI copy, `AGENTS.md` |

## Category Summary

### Domain Model
- Sweep order, policy, position, ledger, audit event, event envelope, and reconciliation break are implemented in Rust and SQL.
- Sweep lifecycle transitions are centralized in `crates/domain/src/sweep.rs`.
- FIDD cash-rail balances are blocked from yield accrual through domain invariant checks.

### Lifecycle State Machine
- The YAML machine, Rust enum, and OpenAPI status enum are checked by `scripts/validate-specs.sh`.
- Invalid transitions return typed domain errors.

### API
- The OpenAPI contract defines health, readiness, policies, sweep orders, redemptions, positions, income, reconciliation breaks, audit events, and local failure injection endpoints.
- All write operations require `Idempotency-Key` and `Correlation-Id`.

### Events
- AsyncAPI channels and JSON Schemas define the local event fanout contract.
- Event envelopes propagate event, aggregate, correlation, causation, and idempotency metadata.

### Persistence
- SQLx migrations create transactional state, append-only ledger, outbox, inbox, idempotency, and audit tables.
- Unique constraints protect idempotent sweep creation and transfer-agent confirmation booking.

### Workers
- Worker kinds consume SQS queues, use inbox deduplication, and only delete messages after successful processing.
- External systems are represented by local mock services and deterministic simulators.

### Frontend
- The React console exposes dashboard, policy/order creation, order detail timeline, positions, reconciliation breaks, health, and local failure injection.
- UI copy distinguishes FIDD cash rails from separate yield-bearing product positions.

### Local Runtime
- Docker Compose is the primary local runtime.
- LocalStack provides SNS/SQS; Postgres provides durable state.

### Kubernetes
- kind manifests are local-first and do not require real AWS.
- AWS-shaped overlays document EKS/IAM/KEDA/HPA patterns without making cloud calls.

### Tests
- Tests cover domain transitions, property invariants, ledger balance rules, persistence idempotency, messaging contract shape, API behavior, frontend behavior, docs/spec validation, and smoke workflows.

### Docs, Security, Observability, Runbooks
- Documentation explains architecture, local development, testing, operations, security posture, production-readiness limits, and recovery runbooks.
- Structured logs, correlation IDs, readiness, liveness, and metrics hooks are implemented or documented.
