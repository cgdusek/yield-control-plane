# Security

The system is local-only by design. It uses dummy secrets, LocalStack, and mock external integrations. It must not be pointed at real AWS or production financial systems.

Data-flow, trust-boundary, classification, and control evidence is tracked in the [DFD evidence pack](security/dfd/README.md).
C4 architecture, container, component, and relationship evidence is tracked in the [C4 evidence pack](architecture/c4/README.md).

## Enforced Local Boundaries

- `AppConfig::validate_local_endpoints` rejects real AWS endpoints in local and dev mode.
- `crates/messaging::validate_local_endpoint` rejects non-local AWS endpoints for LocalStack clients.
- `.env.example`, Compose, Kubernetes, and LocalStack scripts use dummy AWS credentials only.
- API write routes require `Idempotency-Key` and `Correlation-Id` headers.
- `APP_ENV=cert` is the only runtime mode that may use AWS SDK default endpoints, and it requires `AWS_CERTIFICATION_ENABLED=1`, `AWS_REGION=us-west-2`, scoped IAM credentials, and the [AWS simulation runbook](runbooks/aws-simulation.md).

## Data Safety

- FIDD cannot be modeled as a yield-bearing product.
- Ledger rows are append-only in Postgres.
- Duplicate idempotency keys with different bodies are rejected.
- Duplicate transfer-agent confirmation references cannot double-book positions.
- Reconciliation mismatch can be injected locally and produces a break instead of activating silently.

## Local Secrets

The `local-dev-secrets` Kubernetes Secret and Compose environment values contain dummy local values:

```bash
kubectl -n yield-control-plane get secret local-dev-secrets
```

Do not replace these with real credentials in this repository. Production credential handling is documented separately in [Production readiness](production-readiness.md).

## Verification

```bash
cargo test -p institutional-yield-config
cargo test -p institutional-yield-messaging
make smoke-failure-paths
make validate-dfd
make validate-c4
```
