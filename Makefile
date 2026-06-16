.PHONY: check-tools bootstrap validate-specs validate-k8s validate-docs validate fmt lint test dev-up dev-down dev-reset smoke smoke-failure-paths docker-build k8s-up k8s-smoke k8s-down

check-tools:
	./scripts/check-tools.sh

bootstrap:
	./scripts/bootstrap-local.sh

validate-specs:
	./scripts/validate-specs.sh

validate-k8s:
	./scripts/validate-k8s.sh

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
