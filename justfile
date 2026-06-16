set dotenv-load := true

check-tools:
  ./scripts/check-tools.sh

bootstrap:
  ./scripts/bootstrap-local.sh

validate-specs:
  ./scripts/validate-specs.sh

validate-docs:
  ./scripts/validate-docs.sh

validate:
  ./scripts/validate-all.sh

fmt:
  cargo fmt --all --check

lint:
  cargo clippy --workspace --all-targets --all-features -- -D warnings
  pnpm --filter institutional-yield-react-console lint

test:
  cargo test --workspace --all-features
  pnpm --filter institutional-yield-react-console test

dev-up:
  ./scripts/dev-up.sh

dev-down:
  ./scripts/dev-down.sh

dev-reset:
  ./scripts/dev-reset.sh

smoke:
  ./scripts/smoke-create-sweep.sh

smoke-failure-paths:
  ./scripts/smoke-failure-paths.sh

docker-build:
  docker compose build

k8s-up:
  ./scripts/smoke-k8s.sh up

k8s-smoke:
  ./scripts/smoke-k8s.sh smoke

k8s-down:
  ./scripts/smoke-k8s.sh down
