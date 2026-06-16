# Production Readiness

This repository is a local control-plane simulation. The production path is intentionally separated from the local runtime and is not enabled by configuration changes alone.

## Required Changes Before Production

- Replace LocalStack with managed SNS/SQS or an approved production message bus.
- Replace dummy local secrets with a managed secret store and audited rotation.
- Replace the mock transfer agent with a certified external integration.
- Add authentication, authorization, session management, and operator identity to the API and console.
- Add TLS, ingress policy, network policy, persistent storage sizing, backup/restore, disaster recovery, and monitoring.
- Add externally reviewed financial controls for settlement, reconciliation, and ledger accounting.
- Add deployment promotion, rollback, and migration controls.

## Non-Goals Enforced Locally

- No real AWS calls are permitted in local mode.
- No local configuration should be treated as production-safe.
- FIDD yield is not modeled; yield positions are represented by separate product assets such as `FYOXX`.

## Promotion Gate

Before any production adaptation, require:

```bash
make validate
make dev-reset
make dev-up
make smoke
make smoke-failure-paths
make k8s-up
make k8s-smoke
```

Then create a new ADR describing the production infrastructure boundary. Do not mutate the local-only ADRs to imply production readiness.

