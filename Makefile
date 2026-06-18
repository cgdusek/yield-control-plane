.PHONY: check-tools bootstrap generate-formal-coverage-map generate-repo-surface-coverage-map validate-tla validate-source-proofs validate-refinement validate-formal-coverage validate-formal-coverage-map validate-repo-surface-coverage-map validate-liveness validate-specs validate-k8s validate-docs validate-aws-certification validate-standards-readiness validate-dfd validate-c4 validate fmt lint test dev-up dev-down dev-reset smoke smoke-failure-paths docker-build k8s-up k8s-smoke k8s-down aws-cert-bootstrap-iam aws-cert-preflight aws-cert-deploy aws-cert-run aws-cert-collect aws-cert-destroy aws-cert-teardown-iam aws-cert-admission-check aws-cert-wait-queues-drained aws-cert-wait-ecs-services-stable

check-tools:
	./scripts/check-tools.sh

bootstrap:
	./scripts/bootstrap-local.sh

validate-specs:
	./scripts/validate-specs.sh

validate-tla:
	./scripts/validate-tla.sh

validate-source-proofs:
	./scripts/validate-source-proofs.sh

validate-refinement:
	./scripts/validate-refinement.sh

validate-formal-coverage:
	./scripts/validate-formal-coverage.sh

generate-formal-coverage-map:
	./scripts/generate-formal-coverage-map.py

generate-repo-surface-coverage-map:
	./scripts/generate-repo-surface-coverage-map.py

validate-formal-coverage-map:
	./scripts/validate-formal-coverage-map.sh

validate-repo-surface-coverage-map:
	./scripts/validate-repo-surface-coverage-map.sh

validate-liveness:
	./scripts/validate-liveness-coverage.sh

validate-k8s:
	./scripts/validate-k8s.sh

validate-docs:
	./scripts/validate-docs.sh

validate-aws-certification:
	./scripts/validate-aws-certification.sh

validate-standards-readiness:
	./scripts/validate-standards-readiness.sh

validate-dfd:
	./scripts/validate-dfd.sh

validate-c4:
	./scripts/validate-c4.sh

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

aws-cert-bootstrap-iam:
	./scripts/aws-cert-bootstrap-iam.sh

aws-cert-preflight:
	./scripts/aws-cert-preflight.sh

aws-cert-deploy:
	./scripts/aws-cert-deploy.sh

aws-cert-run:
	./scripts/aws-cert-run.sh

aws-cert-collect:
	./scripts/aws-cert-collect.sh

aws-cert-admission-check:
	./scripts/aws-cert-admission-check.sh

aws-cert-wait-queues-drained:
	./scripts/aws-cert-wait-queues-drained.sh

aws-cert-wait-ecs-services-stable:
	./scripts/aws-cert-wait-ecs-services-stable.sh

aws-cert-destroy:
	./scripts/aws-cert-destroy.sh

aws-cert-teardown-iam:
	./scripts/aws-cert-teardown-iam.sh
