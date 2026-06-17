# Testing

The validation strategy is layered. Fast checks run without external services; integration checks use Docker Compose or kind.

## Fast Gate

```bash
make validate-tla
make validate-refinement
make validate-formal-coverage
make validate-liveness
make validate-specs
make validate-k8s
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
pnpm --filter institutional-yield-react-console typecheck
pnpm --filter institutional-yield-react-console lint
pnpm --filter institutional-yield-react-console test
```

## Database Gate

```bash
make dev-up
RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features
```

Database tests run migrations and enforce idempotency, duplicate confirmation rejection, and append-only ledger behavior.

## Runtime Gates

```bash
make smoke
make smoke-failure-paths
make k8s-smoke
```

These gates prove the event path, LocalStack fanout, worker transitions, mock transfer-agent confirmation, reconciliation activation, and failure controls.

## Full Gate

```bash
make validate
```

`make validate` is intended for CI and local pre-commit verification. It runs TLA parsing/proofs/model checking, Rust-to-TLA mapping validation, invariant coverage validation, liveness coverage validation, specs, Kubernetes manifest validation, docs validation, Rust formatting, clippy, Rust tests, frontend install, frontend typecheck, frontend lint, and frontend tests.

## CI

The GitHub Actions workflow at [../.github/workflows/ci.yml](../.github/workflows/ci.yml) runs the static gate and a Docker-backed integration gate using Postgres, LocalStack, DB-backed persistence tests, and smoke scripts.
