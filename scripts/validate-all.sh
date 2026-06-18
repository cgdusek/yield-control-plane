#!/usr/bin/env bash
set -euo pipefail

./scripts/validate-tla.sh
./scripts/validate-source-proofs.sh
./scripts/validate-refinement.sh
./scripts/validate-formal-coverage.sh
./scripts/validate-formal-coverage-map.sh
./scripts/validate-repo-surface-coverage-map.sh
./scripts/validate-liveness-coverage.sh
./scripts/validate-specs.sh
./scripts/validate-k8s.sh
./scripts/validate-aws-certification.sh
./scripts/validate-standards-readiness.sh
./scripts/validate-docs.sh
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
pnpm install --frozen-lockfile
pnpm --filter institutional-yield-react-console typecheck
pnpm --filter institutional-yield-react-console lint
pnpm --filter institutional-yield-react-console test
