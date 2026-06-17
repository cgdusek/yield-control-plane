# Testing

The validation strategy is layered. Fast checks run without external services; integration checks use Docker Compose or kind.

## Fast Gate

```bash
make validate-tla
make validate-source-proofs
make validate-refinement
make validate-formal-coverage
make validate-formal-coverage-map
make validate-repo-surface-coverage-map
make validate-liveness
make validate-specs
make validate-k8s
make validate-aws-certification
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

`make validate` is intended for CI and local pre-commit verification. It runs TLA parsing/proofs/model checking, targeted Kani source proofs for the built-in asset classifier, Rust domain transition, and Rust-to-TLA mapping kernels, Rust-to-TLA mapping validation, invariant coverage validation, generated coverage-map drift checks, liveness coverage validation, specs, Kubernetes manifest validation, AWS certification static validation, docs validation, Rust formatting, clippy, Rust tests, frontend install, frontend typecheck, frontend lint, and frontend tests.

## AWS Certification Static Gate

```bash
make validate-aws-certification
```

This gate validates the AWS simulation command surface, OpenTofu artifact presence, certification coverage map, k6 workload defaults, and fail-closed script guards without making real AWS calls. Real AWS deployment and simulation remain explicit opt-in commands documented in [AWS simulation and internal certification](aws-certification.md).

## CI

The GitHub Actions workflow at [../.github/workflows/ci.yml](../.github/workflows/ci.yml) runs the static gate and a Docker-backed integration gate using Postgres, LocalStack, DB-backed persistence tests, and smoke scripts. The static gate installs Kani before `make validate` so source-proof drift fails CI.
