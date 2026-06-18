# Architecture

The system is a local institutional yield control plane built from independently runnable services. Local AWS dependencies are simulated with LocalStack SNS/SQS; the application refuses real AWS endpoints when `APP_ENV` is `local` or `dev`.

The audit-oriented data-flow view is maintained in the [DFD evidence pack](../security/dfd/README.md).
The audit-oriented C4 architecture view is maintained in the [C4 evidence pack](c4/README.md).

```mermaid
flowchart LR
  Console["React console"] --> API["Rust API"]
  API --> PG["Postgres"]
  API --> Outbox["outbox_events"]
  Outbox --> Publisher["outbox-publisher"]
  Publisher --> SNS["LocalStack SNS"]
  SNS --> SQS1["transfer-agent queue"]
  SNS --> SQS2["reconciliation queue"]
  SNS --> SQS3["notification queue"]
  SNS --> SQS4["chain-watcher queue"]
  SQS1 --> TAWorker["transfer-agent worker"]
  TAWorker --> MockTA["mock transfer agent"]
  TAWorker --> PG
  SQS2 --> Recon["reconciliation worker"]
  Recon --> PG
```

## Runtime Boundaries

- `services/api` exposes OpenAPI-defined routes, health, readiness, metrics, audit events, positions, reconciliation breaks, and local failure controls.
- `services/worker` runs one worker per `WORKER_KIND`: outbox publisher, transfer-agent, reconciliation, notification, and chain-watcher.
- `services/mock-transfer-agent` is the deterministic local stand-in for external subscription confirmation.
- `crates/domain` owns the sweep state machine and financial invariants. API and workers call domain transitions instead of mutating status directly.
- `crates/persistence` owns SQLx migrations, idempotency, append-only ledger enforcement, inbox/outbox, positions, audit records, and reconciliation breaks.

## Enforced Contracts

- FIDD is a cash/payment rail, not a yield-bearing position. The domain and API reject attempts to use FIDD as a yield product.
- `Active` can only follow `Reconciled`; `PositionBooked` requires transfer-agent confirmation.
- Postgres enforces duplicate idempotency, duplicate confirmation refs, and append-only ledger rows.
- LocalStack endpoint validation rejects real AWS endpoints in local mode.
- Workers use outbox/inbox tables so publish and consume behavior is idempotent.

## Verification

```bash
make validate-specs
cargo test --workspace --all-features
RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features
make smoke
make k8s-smoke
make validate-dfd
make validate-c4
```
