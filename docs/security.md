# Security

The system is local-only by design. It uses dummy secrets, LocalStack, and mock external integrations. It must not be pointed at real AWS or production financial systems.

## Enforced Local Boundaries

- `AppConfig::validate_local_endpoints` rejects real AWS endpoints in local and dev mode.
- `crates/messaging::validate_local_endpoint` rejects non-local AWS endpoints for LocalStack clients.
- `.env.example`, Compose, Kubernetes, and LocalStack scripts use dummy AWS credentials only.
- API write routes require `Idempotency-Key` and `Correlation-Id` headers.

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
```

