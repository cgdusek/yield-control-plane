#!/usr/bin/env bash
set -euo pipefail

./scripts/validate-specs.sh
./scripts/validate-k8s.sh
./scripts/validate-docs.sh
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
pnpm install --frozen-lockfile
pnpm --filter institutional-yield-react-console typecheck
pnpm --filter institutional-yield-react-console lint
pnpm --filter institutional-yield-react-console test
