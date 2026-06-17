# Agent Tracker

## Mission
Build `institutional-yield-control-plane`: a local, production-shaped Rust + Postgres + LocalStack SNS/SQS microservices system with a React/TypeScript operator console, specs, ADRs, docs, tests, Docker Compose, and Kubernetes bootstrap artifacts.

## Source Spec
- User request attachment: `/Users/charlesdusek/.codex/attachments/a8cf2c64-a644-453c-a6f4-e8ffd8365a24/pasted-text.txt`
- Preserved project copy: `spec/source/fidelity_defi_yield_platform_spec.md` (pending Gate 1)

## Current Gate
- Gate: Gate 13 formal liveness coverage extension
- Status: Passed
- Start Time: 2026-06-17T02:45:12Z
- End Time: 2026-06-17T03:18:06Z

## Gate Status Table
| Gate | Objective | Status | Evidence | Last Updated |
| --- | --- | --- | --- | --- |
| Gate 0 | Repository and environment discovery | Passed | `pwd`, `ls -la`, `git status --short --branch`, `uname -a`, tool version checks; tracker created | 2026-06-16T14:31:00Z |
| Gate 1 | Source spec ingestion and requirements extraction | Passed | `spec/source/fidelity_defi_yield_platform_spec.md`, `docs/traceability.md` | 2026-06-16T14:36:00Z |
| Gate 2 | Tooling and local bootstrap | Passed | `Makefile`, `justfile`, `.env.example`, `scripts/*.sh`, `docs/bootstrap.md`, `make check-tools` | 2026-06-16T14:45:00Z |
| Gate 3 | Specifications before implementation | Passed | `spec/openapi.yaml`, `spec/asyncapi.yaml`, state machine YAML, JSON schemas, diagrams, TLA model, `make validate-specs` | 2026-06-16T14:56:00Z |
| Gate 4 | Rust workspace and domain core | Passed | `crates/domain`, domain unit/property/invariant tests, `cargo fmt --all --check`, `cargo clippy`, `cargo test --workspace --all-features` | 2026-06-16T15:04:00Z |
| Gate 5 | Persistence, SQL migrations, idempotency, outbox/inbox | Passed | `crates/persistence`, SQL migration, Compose Postgres on 15432, `RUN_DATABASE_TESTS=1 ... cargo test -p institutional-yield-persistence` | 2026-06-16T15:43:00Z |
| Gate 6 | Messaging with LocalStack SNS/SQS | Passed | `crates/messaging`, `scripts/localstack-init.sh`, LocalStack container, SNS publish received from SQS queue | 2026-06-16T16:02:00Z |
| Gate 7 | Rust API service | Passed | `services/api`, config/observability crates, header validation, API tests, Rust fmt/clippy/tests | 2026-06-16T16:16:00Z |
| Gate 8 | Workers and local external simulators | Passed | `services/worker`, `services/mock-transfer-agent`, worker/mock tests, Rust fmt/clippy/tests | 2026-06-16T16:29:00Z |
| Gate 9 | React/TypeScript frontend | Passed | `web/react-console`, pnpm workspace install, typecheck, lint, tests, Vite build | 2026-06-16T16:52:00Z |
| Gate 10 | Docker Compose full local runtime | Passed | `make dev-reset`, `make dev-up`, `make smoke`, `make smoke-failure-paths`, API health, React console HTML, `docker compose ps` | 2026-06-16T15:43:16Z |
| Gate 11 | Kubernetes local bootstrapping | Passed | `make validate-k8s`, `./scripts/install-kind-tooling.sh`, `make k8s-up`, `make k8s-smoke` | 2026-06-16T16:01:27Z |
| Gate 12 | Observability, security, and operations | Passed | Docs/runbooks, `make validate-docs`, `/metrics`, `/audit-events`, `/reconciliation-breaks` | 2026-06-16T16:06:29Z |
| Gate 13 | CI/CD and final verification | Passed | `.github/workflows/ci.yml`, `make validate`, CI YAML parse, DB-backed persistence tests, marker scan | 2026-06-16T16:10:33Z |
| Formal extension | TLAPS/TLC verification spine and invariant traceability | Passed | `make validate-tla`, `make validate-specs`, `make validate-docs`, `make check-tools`, `make validate`; formal docs and tracking artifacts added | 2026-06-17T00:38:18Z |
| Formal refinement hardening | Raw-action TLAPS proofs and Rust-to-TLA refinement-lite evidence | Passed | `make validate` passed with raw-action TLAPS, TLC temporal append-only check, Rust-to-TLA mapping validation, exhaustive Rust transition projection tests, and invariant coverage convergence validator | 2026-06-17T02:36:46Z |
| Formal liveness coverage | Conditional liveness specs, bounded TLC checks, Rust progress tests, runtime evidence, and CI drift gate | Passed | `make validate`, `make smoke`, `make smoke-failure-paths`, DB-backed tests, TLAPS-feasibility validator, worker retry/delete policy tests | 2026-06-17T03:18:06Z |

## Requirements Traceability Summary
- Domain model and state machine: `spec/domain/sweep_order.machine.yaml`, `crates/domain`, domain tests.
- API: `spec/openapi.yaml`, `services/api`, API tests.
- Events and messaging: `spec/asyncapi.yaml`, `spec/schemas/events`, `crates/messaging`, `services/worker`.
- Persistence and financial state: `crates/persistence/migrations`, repositories, idempotency/outbox/inbox code.
- Frontend: `web/react-console`.
- Local runtime: `docker-compose.yml`, `scripts/dev-up.sh`, LocalStack/Postgres scripts.
- Kubernetes: `infra/k8s`.
- Docs, ADRs, runbooks, agentic handoff: `AGENTS.md`, `docs/*`, `docs/adr`, `docs/runbooks`.
- CI and gates: `.github/workflows/ci.yml`, `Makefile`, `scripts/validate-all.sh`.

## Commands Run
| Timestamp | Command | Working Directory | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-06-16T14:28:52Z | `pwd` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Repo path confirmed. |
| 2026-06-16T14:28:52Z | `ls -la` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Empty repo except `.git`. |
| 2026-06-16T14:28:52Z | `git status --short --branch` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | No commits yet on `main`; `origin/main` gone. |
| 2026-06-16T14:28:52Z | `uname -a` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Darwin arm64. |
| 2026-06-16T14:28:52Z | `printf 'SHELL=%s\n' "$SHELL"` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | `/bin/zsh`. |
| 2026-06-16T14:28:52Z | `for t in rustc cargo node npm pnpm docker make just jq curl aws awslocal kubectl kind helm; do ...; done` | `/Users/charlesdusek/Code/yield-control-plane` | Passed with tool-specific gaps | `awslocal`, `kind`, `helm` missing; `kubectl --version` flag unsupported. |
| 2026-06-16T14:28:52Z | `docker compose version` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Docker Compose v5.1.2. |
| 2026-06-16T14:28:52Z | `kubectl version --client=true` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Client v1.34.1, Kustomize v5.7.1. |
| 2026-06-16T14:28:52Z | `pnpm --version` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | pnpm 11.7.0 via Corepack. |
| 2026-06-16T14:28:52Z | `date -u '+%Y-%m-%dT%H:%M:%SZ'` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Timestamp source for tracker. |
| 2026-06-16T14:31:00Z | `mkdir -p spec/source docs/agentic docs/adr docs/runbooks scripts crates services web infra .github/workflows` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Created initial repository directories. |
| 2026-06-16T14:31:00Z | `cp /Users/charlesdusek/.codex/attachments/a8cf2c64-a644-453c-a6f4-e8ffd8365a24/pasted-text.txt spec/source/fidelity_defi_yield_platform_spec.md` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Preserved source request in repo. |
| 2026-06-16T14:36:00Z | `python3 --version` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Python 3.14.5 available for local validation scripts. |
| 2026-06-16T14:36:00Z | `python3 -c 'import yaml; print(yaml.__version__)'` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | PyYAML 6.0.3 available. |
| 2026-06-16T14:36:00Z | `python3 -c 'import jsonschema; print(jsonschema.__version__)'` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | `jsonschema` module is missing; spec validation will use JSON parsing and internal consistency checks instead of external JSON Schema validation. |
| 2026-06-16T14:36:00Z | `mkdir -p spec/domain spec/schemas/events spec/tla spec/diagrams docs/agentic docs/adr docs/runbooks scripts crates/domain/src crates/domain/tests crates/persistence/src crates/persistence/migrations crates/messaging/src crates/observability/src crates/config/src services/api/src/routes services/api/src/middleware services/worker/src/workers services/mock-transfer-agent/src web/react-console/src/api web/react-console/src/components web/react-console/src/pages web/react-console/src/hooks web/react-console/src/styles web/react-console/tests web/react-console/e2e infra/docker/postgres infra/docker/localstack infra/k8s/base infra/k8s/overlays/local infra/k8s/overlays/aws-shaped infra/k8s/kind .github/workflows` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Created requested project directory structure. |
| 2026-06-16T14:36:00Z | `chmod +x scripts/*.sh` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Made local scripts executable. |
| 2026-06-16T14:45:00Z | `make check-tools` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Required tools available; optional `awslocal`, `kind`, `helm` missing and documented. |
| 2026-06-16T14:48:00Z | `chmod +x scripts/validate-specs.sh` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Made spec validator executable. |
| 2026-06-16T14:50:00Z | `make validate-specs` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | OpenAPI, AsyncAPI, JSON syntax, state machine, status enum, and event channel consistency passed. |
| 2026-06-16T14:58:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported formatting diffs in domain crate files and tests. |
| 2026-06-16T14:58:00Z | `cargo test --workspace` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain crate tests passed: 14 tests plus doctests. |
| 2026-06-16T15:00:00Z | `cargo fmt --all` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Applied rustfmt formatting. |
| 2026-06-16T15:00:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain crate clean under clippy deny warnings. |
| 2026-06-16T15:03:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified. |
| 2026-06-16T15:03:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain crate tests passed: 14 tests plus doctests. |
| 2026-06-16T15:12:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported formatting diffs after persistence code additions. |
| 2026-06-16T15:12:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | SQLx `migrate!` and `FromRow` were unavailable because workspace SQLx features lacked `macros` and `derive`. |
| 2026-06-16T15:15:00Z | `cargo fmt --all` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Applied rustfmt after persistence additions. |
| 2026-06-16T15:15:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | `sqlx::migrate::MigrateError` was not convertible into `PersistenceError`. |
| 2026-06-16T15:18:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified after persistence changes. |
| 2026-06-16T15:18:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Clippy rejected two helper functions with too many arguments. |
| 2026-06-16T15:18:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain tests passed; persistence tests compile and skip DB work unless `RUN_DATABASE_TESTS=1`. |
| 2026-06-16T15:23:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified. |
| 2026-06-16T15:23:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain and persistence crates clean under clippy deny warnings. |
| 2026-06-16T15:23:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain tests pass; persistence DB tests compile and are gated by `RUN_DATABASE_TESTS=1`. |
| 2026-06-16T15:24:00Z | `docker compose up -d postgres` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Docker CLI is installed, but Docker daemon socket `/Users/charlesdusek/.docker/run/docker.sock` is unavailable. |
| 2026-06-16T15:25:00Z | `open -a Docker` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Started Docker Desktop through macOS. |
| 2026-06-16T15:25:00Z | `for i in $(seq 1 90); do if docker info ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Docker daemon became ready. |
| 2026-06-16T15:26:00Z | `docker compose up -d postgres` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Postgres image pulled and container started. |
| 2026-06-16T15:27:00Z | `for i in $(seq 1 60); do status=$(docker inspect ...` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | zsh treats `status` as read-only. |
| 2026-06-16T15:28:00Z | `for i in $(seq 1 60); do hstatus=$(docker inspect ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Postgres container healthcheck reported healthy. |
| 2026-06-16T15:29:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@localhost:5432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Postgres returned `role "yield" does not exist`; local volume has unexpected initialization state. |
| 2026-06-16T15:31:00Z | `docker compose down -v` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Reset local Compose volumes. |
| 2026-06-16T15:31:00Z | `docker compose up -d postgres && for i in $(seq 1 60); do hstatus=...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Postgres restarted and became healthy. |
| 2026-06-16T15:32:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:5432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Host-local Postgres on 127.0.0.1:5432 shadowed the Compose port and lacks role `yield`. |
| 2026-06-16T15:33:00Z | `lsof -nP -iTCP:5432 -sTCP:LISTEN` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Found host Postgres PID 838 on 127.0.0.1:5432 and Docker proxy on *:5432. |
| 2026-06-16T15:35:00Z | `docker compose down -v && docker compose up -d postgres && for i in $(seq 1 60); do hstatus=...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Recreated Postgres on host port 15432 and reached healthy state. |
| 2026-06-16T15:36:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Tests reached Compose DB but concurrent truncation caused Postgres deadlocks. |
| 2026-06-16T15:39:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings`; `cargo test --workspace --all-features`; `RUN_DATABASE_TESTS=1 ... cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Serialized DB test patch left one `&&PgPool` executor call in append-only test. |
| 2026-06-16T15:42:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified. |
| 2026-06-16T15:42:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain and persistence crates clean under clippy deny warnings. |
| 2026-06-16T15:42:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain and persistence tests passed; DB tests compile and skip unless enabled. |
| 2026-06-16T15:42:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | 5 Postgres-backed persistence tests passed with migrations, constraints, idempotency, duplicate confirmation, and append-only ledger trigger. |
| 2026-06-16T15:47:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported formatting diffs in messaging crate files. |
| 2026-06-16T15:48:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain, persistence, and messaging unit tests passed after AWS SDK dependencies compiled. |
| 2026-06-16T15:50:00Z | `cargo fmt --all` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Applied rustfmt to messaging crate. |
| 2026-06-16T15:50:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Clippy flagged manual contains logic and oversized AWS SDK error variants. |
| 2026-06-16T15:52:00Z | `cargo fmt --all --check`; `cargo clippy --workspace --all-targets --all-features -- -D warnings`; `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Domain, persistence, and messaging crates passed Rust gates. |
| 2026-06-16T15:55:00Z | `docker compose up -d localstack && for i in $(seq 1 90); do curl ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | LocalStack image pulled, container started, health endpoint reachable. |
| 2026-06-16T15:56:00Z | `LOCALSTACK_ENDPOINT=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 ./scripts/localstack-init.sh` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | AWS CLI rejected comma shorthand attributes with embedded RedrivePolicy JSON. |
| 2026-06-16T15:58:00Z | `LOCALSTACK_ENDPOINT=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 ./scripts/localstack-init.sh` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | SNS topic, worker queues, and DLQs created with subscriptions. |
| 2026-06-16T15:59:00Z | `topic_arn=$(aws --endpoint-url http://localhost:4566 ... sns publish ...) ... sqs receive-message ...` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Dummy AWS credentials were not exported for the ad hoc AWS CLI fanout check. |
| 2026-06-16T16:01:00Z | `export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1; topic_arn=$(aws --endpoint-url http://localhost:4566 ...); aws sns publish ...; aws sqs receive-message ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Published raw event was received from `transfer-agent-worker-queue`. |
| 2026-06-16T16:08:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported formatting diffs in API service files. |
| 2026-06-16T16:08:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | API tests passed with header enforcement and FIDD-yield rejection, along with workspace tests. |
| 2026-06-16T16:12:00Z | `cargo fmt --all` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Applied rustfmt to API service. |
| 2026-06-16T16:12:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | API, config, observability, domain, messaging, persistence clean under clippy. |
| 2026-06-16T16:15:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified. |
| 2026-06-16T16:15:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Workspace tests passed, including 2 API tests. |
| 2026-06-16T16:24:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported formatting diffs in worker files. |
| 2026-06-16T16:24:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Worker and mock transfer-agent tests passed with workspace tests. |
| 2026-06-16T16:26:00Z | `cargo fmt --all` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Applied rustfmt to worker files. |
| 2026-06-16T16:26:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Worker and mock services clean under clippy. |
| 2026-06-16T16:28:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust formatting verified. |
| 2026-06-16T16:28:00Z | `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Workspace tests passed, including worker/mock tests. |
| 2026-06-16T16:37:00Z | `pnpm --dir web/react-console install` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | pnpm 11 ignored `esbuild` build scripts and required explicit approval. |
| 2026-06-16T16:38:00Z | `pnpm --dir web/react-console install` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | pnpm no longer reads package-level `pnpm.onlyBuiltDependencies`; setting must live in workspace config. |
| 2026-06-16T16:39:00Z | `pnpm install` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Workspace `onlyBuiltDependencies` was recognized, but pnpm still required explicit `allowBuilds.esbuild`. |
| 2026-06-16T16:40:00Z | `pnpm config list`; `pnpm config get onlyBuiltDependencies`; `pnpm config get ignoredBuiltDependencies` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Confirmed pnpm reads `onlyBuiltDependencies` and reports `allowBuilds.esbuild` needs a boolean. |
| 2026-06-16T16:41:00Z | `pnpm install` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | `pnpm-workspace.yaml` had duplicate `allowBuilds` keys after pnpm inserted a placeholder. |
| 2026-06-16T16:42:00Z | `pnpm install` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Workspace install succeeded and ran esbuild postinstall under explicit allowlist. |
| 2026-06-16T16:43:00Z | `pnpm --dir web/react-console typecheck`; `pnpm --dir web/react-console lint`; `pnpm --dir web/react-console test -- --run` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | `--dir` command path triggered pnpm deps-status install that ignored workspace build policy. |
| 2026-06-16T16:48:00Z | `pnpm --filter institutional-yield-react-console typecheck`; `pnpm --filter institutional-yield-react-console lint`; `pnpm --filter institutional-yield-react-console test -- --run` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | TypeScript lacked Vite env typing, Vitest config typing/globals, and test used `global`; Vitest command passed an extra `--`. |
| 2026-06-16T16:50:00Z | `pnpm --filter institutional-yield-react-console typecheck`; `pnpm --filter institutional-yield-react-console lint`; `pnpm --filter institutional-yield-react-console test` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Frontend typecheck, lint script, and 2 tests passed. |
| 2026-06-16T16:51:00Z | `pnpm --filter institutional-yield-react-console build` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Vite production build succeeded. |
| 2026-06-16T16:59:00Z | `docker compose config --quiet` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Compose file validates after full service wiring. |
| 2026-06-16T16:59:00Z | `cargo fmt --all --check` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | rustfmt reported one wrap in worker reconciliation guard. |
| 2026-06-16T16:59:00Z | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust workspace clean under clippy after worker runtime patch. |
| 2026-06-16T16:59:00Z | `pnpm --filter institutional-yield-react-console build` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Frontend build still succeeds after Dockerfile updates. |
| 2026-06-16T15:22:57Z | `cargo fmt --all --check`; `cargo clippy --workspace --all-targets --all-features -- -D warnings`; `cargo test --workspace --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust workspace verified after the last formatting pass. |
| 2026-06-16T15:23:00Z | `pnpm install`; `docker compose config --quiet` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Added Node typing for configurable Vite proxy and revalidated Compose syntax. |
| 2026-06-16T15:24:00Z | `pnpm --filter institutional-yield-react-console typecheck`; `lint`; `test`; `build` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Frontend checks passed after Docker/host proxy target split. |
| 2026-06-16T15:26:00Z | `make dev-reset` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Reset partial Compose state and removed Postgres/LocalStack volumes. |
| 2026-06-16T15:31:00Z | `make dev-up` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | React console Docker build failed because `pnpm build` in the package subdirectory attempted noninteractive module purge. |
| 2026-06-16T15:32:00Z | `make dev-reset` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Reset failed partial build runtime before retry. |
| 2026-06-16T15:38:00Z | `make dev-up` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Built API, worker, mock transfer-agent, and React console images; started all services healthy/running. |
| 2026-06-16T15:38:00Z | `make smoke` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Created order and workers advanced it through Created -> Active with a booked position and transfer-agent confirmation. |
| 2026-06-16T15:39:00Z | `make smoke-failure-paths` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Negative smoke checks passed, including FIDD yield rejection and reconciliation failure path. |
| 2026-06-16T15:42:00Z | `curl -fsS http://localhost:8080/health`; `curl -fsS http://localhost:5173`; `docker compose ps` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | API health returned ok, React console served HTML, and all Compose services were running with expected health. |
| 2026-06-16T15:51:00Z | `kubectl kustomize infra/k8s/overlays/local`; `kubectl kustomize infra/k8s/overlays/aws-shaped` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Both Kubernetes overlays rendered successfully. |
| 2026-06-16T15:51:00Z | `kubectl apply --dry-run=client --validate=false -f /tmp/ycp-k8s-*.yaml` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | This kubectl client still queried a live API server for discovery, so offline validation moved to a manifest parser. |
| 2026-06-16T15:54:00Z | `make validate-k8s` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Local and aws-shaped overlays rendered 19 resources each and passed offline invariant checks. |
| 2026-06-16T15:55:00Z | `./scripts/install-kind-tooling.sh` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Installed kind 0.32.0 and helm 4.2.1 through Homebrew. |
| 2026-06-16T16:00:00Z | `make k8s-up` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Created kind cluster, built/loaded local images, applied manifests, completed LocalStack init Job, and rolled out all deployments. |
| 2026-06-16T16:01:00Z | `make k8s-smoke` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Kubernetes happy-path smoke created an order and workers advanced it to Active with a booked position. |
| 2026-06-16T16:04:00Z | `make validate-docs` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Existing working-agreement wording used an unfinished-work marker now banned by the docs validator. |
| 2026-06-16T16:05:00Z | `make validate-docs` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Documentation links, required docs, runbooks, and enforcement markers validated. |
| 2026-06-16T16:06:00Z | `curl -fsS http://localhost:8080/metrics`; `curl -fsS http://localhost:8080/audit-events | jq 'length'`; `curl -fsS http://localhost:8080/reconciliation-breaks | jq 'length'` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Metrics responded; Compose runtime reported 28 audit events and 2 reconciliation breaks from smoke tests. |
| 2026-06-16T16:09:00Z | `make validate` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Spec validation, Kubernetes manifest validation, docs validation, Rust fmt/clippy/tests, pnpm install, frontend typecheck/lint/tests all passed. |
| 2026-06-16T16:09:00Z | `python3 - <<'PY' ... yaml.safe_load('.github/workflows/ci.yml')` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | CI workflow YAML parsed successfully. |
| 2026-06-16T16:09:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | 5 Postgres-backed persistence tests passed against running Compose Postgres. |
| 2026-06-16T16:10:00Z | `git status --short --branch` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Repository is new with all generated files untracked; no pre-existing user files were overwritten. |
| 2026-06-16T16:10:00Z | `rg -n "TODO|FIXME|TBD|placeholder|coming soon|lorem ipsum" ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed with intentional matches | Matches are rule text, historical tracker evidence, validator pattern, preserved source request, and a functional UI input hint. |
| 2026-06-17T00:19:02Z | `rg --files ...`, `sed -n ...`, `command -v tlapm`, `java -version`, `brew search tla` | `/Users/charlesdusek/Code/yield-control-plane` | Passed with tool gap | Formal verification workstream started. Current repo has only `spec/tla/no_double_sweep.tla`; Java 17 and Homebrew are present; `tlapm` and `tla2tools.jar` are not yet available. |
| 2026-06-17T00:34:16Z | `make validate-tla` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | SANY parsed the TLA modules; TLAPS proved 32 obligations in `YieldProofs.tla` and 1 in `no_double_sweep.tla`; TLC explored 3,627 distinct states with no error. |
| 2026-06-17T00:36:19Z | `make validate-tla`; `make validate-specs`; `make validate-docs` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Formal, spec, and documentation gates passed after adding docs and validator wiring. |
| 2026-06-17T00:37:02Z | `make check-tools` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Java is now required; repo-local TLAPS 1.5.0 is detected as optional tooling. |
| 2026-06-17T00:38:09Z | `make validate` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Full static validation passed with formal gate first, then specs, Kubernetes validation, docs, Rust fmt/clippy/tests, pnpm install, frontend typecheck/lint/tests. |
| 2026-06-17T00:38:18Z | `test ! -d .tlacache && test ! -d states`; `rg -n "TODO|FIXME|TBD|placeholder|coming soon|lorem ipsum" ...`; `git status --short` | `/Users/charlesdusek/Code/yield-control-plane` | Passed with intentional marker matches | Generated TLAPS/TLC state is clean; marker matches are the standing rule text, validator pattern, and historical tracker evidence. |
| 2026-06-17T01:47:51Z | `git status --short`; `sed -n ... AGENT_TRACKER.md spec/tla/YieldLifecycle.tla spec/tla/YieldProofs.tla crates/domain/src/sweep.rs crates/domain/tests/sweep_property_tests.rs` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Formal refinement hardening started from the existing uncommitted formal-verification extension; no generated TLAPS/TLC state present at start. |
| 2026-06-17T01:54:40Z | `make validate-tla` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | After removing safety-guarded `ActionSafe`, TLAPS rejected raw preservation obligations, led by the generic `MovePreservesInv` lemma allowing a `NoStatus` move that Rust never permits. |
| 2026-06-17T02:12:43Z | `make validate-tla`; `quick_validate.py ~/.codex/skills/coverage-convergence-loop`; `coverage_round.py ... summary --require-complete` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Formal gate recovered after replacing tabs in `YieldInvariants.tla`; created and validated personal skill `~/.codex/skills/coverage-convergence-loop` for round-by-round TLA+/TLAPS/Rust/enforcement coverage closure. |
| 2026-06-17T02:16:27Z | `sed -n ...`; `rg -n ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Formal convergence round started; inspected invariant catalog, TLC config, TLAPS theorems, Rust refinement tests, validators, and full gate wiring. |
| 2026-06-17T02:23:22Z | `make validate-formal-coverage`; `make validate-tla`; `make validate-refinement`; `make validate-specs`; `make validate-docs`; `make validate`; `test ! -d .tlacache && test ! -d states` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Added `spec/refinement/invariant_coverage.yaml`, `scripts/validate-formal-coverage.sh`, explicit TLC `LedgerAppendOnlyTemporal`, docs/gate wiring, and verified full static validation with no generated TLA state left behind. |
| 2026-06-17T02:32:05Z | `git status --short`; `sed -n ...`; `rg ...` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Started an additional formal refinement hardening round focused on exhaustive Rust transition projection and static proof coverage for every TLA `Next` action. |
| 2026-06-17T02:34:00Z | `cargo test -p institutional-yield-domain --test refinement_trace_tests`; `make validate-refinement` | `/Users/charlesdusek/Code/yield-control-plane` | Failed / Passed | Rust refinement test exposed a brittle hard-coded declared-path count; static refinement validator passed with TLA `Next` preservation coverage. |
| 2026-06-17T02:36:00Z | `cargo test -p institutional-yield-domain --test refinement_trace_tests`; `make validate-refinement` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rust refinement tests now load `rust_tla_mapping.yaml`, exercise declared transition paths against `transition(...)`, and reject accepted Rust transitions missing mapping evidence. |
| 2026-06-17T02:35:00Z | `cargo fmt --all --check`; `make validate-tla`; `make validate-formal-coverage`; `make validate-docs` | `/Users/charlesdusek/Code/yield-control-plane` | Failed / Passed / Passed / Passed | Rustfmt caught one wrapping diff in the new test; TLAPS proved 131 obligations, TLC completed with 5,643 distinct states and no errors, formal coverage and docs passed. |
| 2026-06-17T02:36:46Z | `cargo fmt --all`; `cargo fmt --all --check`; `cargo test -p institutional-yield-domain --test refinement_trace_tests`; `make validate-refinement`; `make validate`; `test ! -d .tlacache && test ! -d states`; `git status --short`; marker scan | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Full static validation passed after F6 hardening; generated TLA state is clean; marker scan has only intentional historical/rule/source/UI matches. |
| 2026-06-17T02:36:46Z | `make validate-docs`; `test ! -d .tlacache && test ! -d states` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Final tracker/doc updates validated; generated TLA state remains clean. |
| 2026-06-17T02:45:12Z | `git commit -m "Add formal verification and refinement gates"`; `git push origin main`; `git status -sb`; `git rev-parse --short HEAD` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Committed and pushed completed formal safety/refinement baseline `d288365` to `origin/main` before liveness work. |
| 2026-06-17T02:48:23Z | `make validate-tla` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | New lifecycle liveness model reached intended `Settled` terminal state and TLC reported deadlock because no further progress action is enabled. |
| 2026-06-17T02:49:13Z | `make validate-tla` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Safety TLAPS/TLC passed; lifecycle, exception, and messaging liveness TLC configs completed with no errors after disabling deadlock checks for terminal progress models. |
| 2026-06-17T02:50:00Z | `cargo test -p institutional-yield-domain --test liveness_trace_tests`; `cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Added domain progress trace tests and persistence outbox/inbox progress tests; persistence DB cases follow existing `RUN_DATABASE_TESTS=1` gating. |
| 2026-06-17T02:51:00Z | `make validate-liveness` | `/Users/charlesdusek/Code/yield-control-plane` | Failed then Passed | Liveness validator caught stale evidence paths; corrected matrix references and liveness coverage validation passed. |
| 2026-06-17T03:03:49Z | `make dev-reset`; `make dev-up` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Removed stale Compose containers/volumes, rebuilt current API/worker/mock/frontend images, and brought the fresh local runtime up healthy. |
| 2026-06-17T03:03:49Z | edit `spec/refinement/liveness_coverage.yaml`, `scripts/validate-liveness-coverage.sh`, `docs/liveness-verification.md` | `/Users/charlesdusek/Code/yield-control-plane` | In Progress | Hardened the liveness validator design so every property must cite TLAPS safety proof evidence where feasible, or explicitly classify temporal fairness obligations as not directly TLAPS-feasible. |
| 2026-06-17T03:04:00Z | `make validate-liveness` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Hardened liveness validator parsed `YieldProofs.tla`, checked TLAPS feasibility metadata, and verified theorem evidence. |
| 2026-06-17T03:05:00Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | 7 DB-backed persistence tests passed, including outbox retry and inbox dedupe progress tests. |
| 2026-06-17T03:06:00Z | `make smoke` | `/Users/charlesdusek/Code/yield-control-plane` | Failed | Transfer-agent worker had exited on a stale test-created message; smoke order remained `Created`. |
| 2026-06-17T03:08:00Z | `cargo fmt --all --check`; `cargo test -p institutional-yield-worker --all-features` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Added worker consumer-loop retry/delete policy and unit tests for handler, inbox-recording, and malformed-message failures. |
| 2026-06-17T03:15:00Z | `make dev-reset`; `make dev-up`; `make smoke`; `make smoke-failure-paths` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Rebuilt patched worker image from clean volumes; happy-path smoke reached `Active`; failure-path smoke passed. |
| 2026-06-17T03:16:17Z | `RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features`; `sleep 3 && docker compose ps` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | DB-backed tests passed against the live runtime and all workers remained up afterward. |
| 2026-06-17T03:17:45Z | `make validate` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Full gate passed: SANY, TLAPS 131+1 obligations, TLC safety/liveness checks, refinement/formal/liveness coverage validators, specs, k8s manifests, docs, Rust fmt/clippy/tests, and frontend checks. |
| 2026-06-17T03:18:00Z | `make dev-down` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Local Compose runtime stopped and containers/network removed. |
| 2026-06-17T03:18:06Z | `test ! -d .tlacache && test ! -d states`; `git status -sb`; marker scan | `/Users/charlesdusek/Code/yield-control-plane` | Passed with intentional marker matches | Generated TLAPS/TLC state is clean; marker matches are standing rule text, historical tracker evidence, validator pattern, preserved source request, and UI input hint. |
| 2026-06-17T03:18:06Z | `make validate-docs` | `/Users/charlesdusek/Code/yield-control-plane` | Passed | Tracker closure edits validated. |

## Decisions Made
- 2026-06-16T14:48:00Z: User added a hard constraint that no artifact may be ornamental, decorative, inert, or merely skeletal. Every artifact must be executable, validated, enforced by tests/scripts/policies, or explicitly tracked as a bounded deferral. Added to `AGENTS.md` and `docs/agentic/working-agreement.md`.
- ADR-0001 through ADR-0012 accepted for workspace, LocalStack, Postgres/SQLx, domain state machine, outbox/inbox, frontend, Compose, kind, mocks, no real AWS, production deltas, and safety invariants.
- 2026-06-17T00:19:02Z: Formal verification extension will be bound to `make validate` through `scripts/validate-tla.sh`; TLAPS proofs and TLC bounded checks must be reported separately because TLAPS is an unbounded safety proof layer while TLC is bounded model checking.
- 2026-06-17T00:38:18Z: Formal proof boundary is explicit: TLAPS checks the abstract safety-guarded protocol, TLC checks bounded interleavings, and Rust/SQL/runtime gates provide implementation conformance evidence rather than a full Rust-to-TLA refinement proof.
- 2026-06-17T01:47:51Z: Formal refinement hardening will replace safety-guarded action proofs with raw-action preservation where TLAPS can check them, and will add executable Rust-to-TLA mapping evidence without claiming a full source-level refinement proof.
- 2026-06-17T02:32:05Z: Additional refinement hardening will fail the gate if a TLA `Next` action lacks a `PreservesInv` theorem, or if any declared Rust transition path no longer projects to the matching TLA action.
- 2026-06-17T02:45:12Z: Formal liveness coverage is scoped to conditional progress under explicit fairness and environment assumptions, plus bounded TLC model checks and Rust/runtime evidence. It does not claim universal progress under arbitrary external failure.
- 2026-06-17T03:03:49Z: The liveness coverage validator must require TLAPS theorem evidence for every mathematically feasible safety obligation supporting a progress path. Pure temporal fairness/eventuality claims must be explicitly classified as not directly TLAPS-feasible and remain bounded by TLC/Rust/runtime evidence.
- 2026-06-17T03:16:17Z: Worker consumers must not exit on per-message failures. Malformed messages are deleteable poison messages; inbox-recording or handler failures are logged and left for retry so stale or transient messages do not halt liveness for later messages.

## Defects / Failures
| Timestamp | Failure | Root-Cause Hypothesis | Mitigation | Follow-Up Gate |
| --- | --- | --- | --- | --- |
| 2026-06-16T14:28:52Z | `kubectl --version` returned `error: unknown flag: --version` during generic tool loop. | Installed kubectl expects `kubectl version --client=true`. | Re-ran with supported flag and recorded v1.34.1. | Gate 0 |
| 2026-06-16T14:36:00Z | Python `jsonschema` module not installed. | Local Python environment does not include optional JSON Schema validator. | `scripts/validate-specs.sh` will validate JSON syntax and cross-file consistency without requiring that module. | Gate 3 |
| 2026-06-16T14:58:00Z | `cargo fmt --all --check` failed. | Newly added Rust files had rustfmt-normalizable formatting. | Run `cargo fmt --all`, then rerun format/clippy/test. | Gate 4 |
| 2026-06-16T15:12:00Z | Persistence build failed on SQLx macros and derives. | Workspace SQLx features omitted `macros` and `derive`, so migration macro and `sqlx::FromRow` derives were gated out. | Added `macros` and `derive` to the workspace SQLx dependency and rerun Rust gates. | Gate 5 |
| 2026-06-16T15:15:00Z | Persistence build failed on migration error conversion. | `migrate()` used `?` on `MigrateError`, but `PersistenceError` did not implement `From<MigrateError>`. | Added `Migrate(#[from] sqlx::migrate::MigrateError)` to `PersistenceError`. | Gate 5 |
| 2026-06-16T15:18:00Z | Clippy failed on helper argument count. | Persistence helper functions encoded transition and ledger-entry parameters as long positional lists. | Replace positional lists with typed parameter structs and rerun clippy. | Gate 5 |
| 2026-06-16T15:24:00Z | `docker compose up -d postgres` failed because Docker daemon is unavailable. | Docker Desktop or daemon is not currently running. | Attempt non-destructive `open -a Docker`; if daemon remains unavailable, document Gate 5 runtime DB validation as blocked and continue with compile/test evidence plus runnable Compose/scripts. | Gate 5 / Gate 10 |
| 2026-06-16T15:27:00Z | zsh healthcheck loop failed on read-only variable `status`. | `status` is reserved/read-only in zsh. | Rerun with `hstatus` variable. | Gate 5 |
| 2026-06-16T15:29:00Z | DB-backed persistence tests failed because role `yield` does not exist. | The Postgres data volume likely initialized before the intended Compose environment or with a conflicting role. | Reset the local Compose Postgres volume and rerun `RUN_DATABASE_TESTS=1` tests. | Gate 5 |
| 2026-06-16T15:33:00Z | DB-backed tests still reached a Postgres without `yield` after reset. | A host Postgres is bound to 127.0.0.1:5432, shadowing Compose for local test connections. | Move Compose host port to 15432 and update local URLs. | Gate 5 / Gate 10 |
| 2026-06-16T15:36:00Z | DB-backed tests deadlocked during concurrent setup. | Rust tests run concurrently and each test truncated shared tables while other tests were creating rows. | Add an async mutex around test database setup/use so DB integration tests serialize themselves. | Gate 5 |
| 2026-06-16T15:39:00Z | Persistence test build failed on `&&PgPool`. | A refactor changed `pool` to `&PgPool`, but one direct SQLx call still passed `&pool`. | Pass `pool` directly to SQLx executor. | Gate 5 |
| 2026-06-16T15:47:00Z | `cargo fmt --all --check` failed after messaging additions. | New AWS SDK wrapper files needed rustfmt line wrapping. | Run `cargo fmt --all`, then rerun format/clippy. | Gate 6 |
| 2026-06-16T15:50:00Z | Messaging clippy failed on helper and error enum. | `event_matches` used manual `iter().any`, and AWS SDK error variants made `MessagingError` too large. | Use `contains` and map SDK operation errors to compact string variants. | Gate 6 |
| 2026-06-16T15:56:00Z | `scripts/localstack-init.sh` failed parsing queue attributes. | AWS CLI shorthand syntax cannot parse an embedded JSON RedrivePolicy in the comma-separated attribute string. | Use JSON-form `--attributes` maps for create-queue and set-queue-attributes. | Gate 6 |
| 2026-06-16T15:59:00Z | Ad hoc LocalStack fanout check failed with `NoCredentials`. | The one-line check did not export dummy LocalStack AWS credentials. | Rerun with `AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1`. | Gate 6 |
| 2026-06-16T16:08:00Z | `cargo fmt --all --check` failed after API additions. | New API files needed rustfmt line wrapping. | Run `cargo fmt --all`, then rerun format/clippy. | Gate 7 |
| 2026-06-16T16:24:00Z | `cargo fmt --all --check` failed after worker additions. | New worker files needed rustfmt line wrapping. | Run `cargo fmt --all`, then rerun format/clippy. | Gate 8 |
| 2026-06-16T16:37:00Z | Frontend install failed on ignored build scripts. | pnpm 11 requires explicit allowlisting for packages with build scripts. | Add `pnpm.onlyBuiltDependencies = ["esbuild"]` to `web/react-console/package.json` and rerun install. | Gate 9 |
| 2026-06-16T16:38:00Z | Frontend install still failed because package-level pnpm setting is ignored. | pnpm 11 moved build-script policy to workspace settings. | Add root `pnpm-workspace.yaml` with `onlyBuiltDependencies: [esbuild]`. | Gate 9 |
| 2026-06-16T16:40:00Z | Root pnpm install still failed on ignored `esbuild` build. | pnpm recognized the dependency list but also exposed `allowBuilds.esbuild` as unset. | Add `allowBuilds.esbuild: true` to `pnpm-workspace.yaml`. | Gate 9 |
| 2026-06-16T16:41:00Z | `pnpm-workspace.yaml` parse failed due duplicate key. | pnpm had written an `allowBuilds` placeholder, and the manual patch added a second key. | Remove placeholder and keep `allowBuilds.esbuild: true`. | Gate 9 |
| 2026-06-16T16:43:00Z | Frontend validation failed when run with `pnpm --dir`. | `--dir` bypassed effective workspace policy during pnpm deps-status check. | Use root workspace commands with `--filter institutional-yield-react-console` in Makefile, justfile, and validate script. | Gate 9 |
| 2026-06-16T16:48:00Z | Frontend typecheck and tests failed on explicit typing/config issues. | Vite env and Vitest config types were not declared; Vitest globals were disabled; test used `global` instead of `globalThis`; test command duplicated args. | Add Vite/Vitest types, import config from `vitest/config`, enable globals, use `globalThis`, and make `test` run `vitest run`. | Gate 9 |
| 2026-06-16T16:59:00Z | `cargo fmt --all --check` failed after worker idempotency guard. | One new `matches!` expression needed rustfmt line wrapping. | Run `cargo fmt --all`, then rerun format/tests. | Gate 10 |
| 2026-06-16T15:31:00Z | `make dev-up` failed in React console Docker build. | Running `pnpm build` from `/app/web/react-console` triggered pnpm's deps-status install check, which tried to purge modules without a TTY. | Run build and dev commands from the root workspace with `pnpm --filter institutional-yield-react-console ...`; add `.dockerignore` to keep Docker contexts bounded. | Gate 10 |
| 2026-06-16T15:51:00Z | `kubectl apply --dry-run=client --validate=false` could not validate without an API server. | The installed kubectl still performs discovery even with client dry-run and validation disabled. | Added `scripts/validate-k8s.sh` to render overlays and enforce Kubernetes invariants offline with PyYAML. | Gate 11 |
| 2026-06-16T16:04:00Z | `make validate-docs` failed on `docs/agentic/working-agreement.md`. | The new validator correctly rejected unfinished-work marker language in an existing guide. | Reworded the guide while preserving the enforceable-artifact rule, then reran docs validation. | Gate 12 |
| 2026-06-17T01:54:40Z | Raw `make validate-tla` failed in `YieldProofs.tla`. | The shared `Move` action was too broad for Rust refinement because it admitted moving an uncreated order without setting non-FIDD product metadata; several wrapper lemmas inherited that invalid abstraction. | Constrain lifecycle moves to existing orders, decompose wrappers into direct action proofs where TLAPS needs concrete status facts, then rerun `make validate-tla`. | Formal refinement hardening |
| 2026-06-17T02:34:00Z | `cargo test -p institutional-yield-domain --test refinement_trace_tests` failed after F6 test addition. | The new test hard-coded 35 declared transition paths, but `rust_tla_mapping.yaml` declares 38 paths including all exception-opening statuses. | Replace the magic count with a YAML-derived expected path count and rerun the refinement test. | Formal refinement hardening |
| 2026-06-17T02:48:23Z | `make validate-tla` failed after adding liveness configs. | TLC deadlock checking is inappropriate for finite progress models that intentionally stop at terminal statuses after satisfying liveness properties. | Add `CHECK_DEADLOCK FALSE` to liveness configs and keep the safety config's deadlock behavior unchanged. | Formal liveness coverage |
| 2026-06-17T03:03:49Z | Initial post-liveness `make smoke` and `make smoke-failure-paths` attempts returned HTTP 404. | The long-running Compose API container was serving a stale image from before the current `/ready` route and liveness changes. | Run `make dev-reset` and fresh `make dev-up` to rebuild current images before rerunning smoke gates. | Formal liveness coverage |
| 2026-06-17T03:06:00Z | `make smoke` stalled at `Created` and failed after polling. | DB-backed tests had inserted outbox events while runtime workers were up; after test cleanup, a stale queued event made the transfer-agent worker return `record not found` and exit because the consumer propagated handler errors. | Make queue consumers log per-message failures and continue; leave handler/inbox failures for retry, delete malformed poison messages, add worker tests, rebuild runtime, and rerun smoke gates. | Formal liveness coverage |

## Environment
- OS: Darwin Tao.local 25.5.0 arm64
- Shell: `/bin/zsh`
- Rust: `rustc 1.95.0`, `cargo 1.95.0`
- Node: `v24.15.0`
- npm: `11.12.1`
- pnpm: `11.7.0`
- Docker: `29.4.0`
- Docker Compose: `v5.1.2`
- make: GNU Make 3.81
- just: 1.49.0
- jq: 1.7.1
- curl: 8.7.1
- aws: aws-cli/2.34.32
- awslocal: missing
- kubectl: v1.34.1
- kind: missing
- helm: missing

## Final Verification
- `make validate` passed.
- `make validate-tla` passed.
- `make validate-liveness` passed with TLAPS theorem evidence required where feasible.
- `make dev-up` passed; `make dev-down` passed after smoke validation.
- `make smoke` passed.
- `make smoke-failure-paths` passed.
- Worker consumer-loop retry/delete policy tests passed.
- `make validate-k8s` passed.
- `make k8s-up` passed and the kind runtime is running.
- `make k8s-smoke` passed.
- DB-backed persistence tests passed with `RUN_DATABASE_TESTS=1`.
- CI workflow YAML parsed successfully.
