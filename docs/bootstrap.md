# Local Bootstrap

The local stack is self-contained and uses dummy credentials only. It does not call real AWS.

## Required Tools

- Rust stable toolchain
- Node.js and pnpm through Corepack
- Docker with Docker Compose
- make
- jq
- curl
- AWS CLI
- kubectl for manifest validation and the optional kind path

Run:

```bash
make check-tools
make bootstrap
```

## Optional Kubernetes Tools

The Docker Compose runtime is the primary local path. The kind demo additionally needs:

- kind
- helm

On macOS with Homebrew:

```bash
./scripts/install-kind-tooling.sh
```

If Homebrew is unavailable, install kind and helm from their upstream instructions:

- <https://kind.sigs.k8s.io/docs/user/quick-start/#installation>
- <https://helm.sh/docs/intro/install/>

## Environment

The defaults are safe for local development. To override them:

```bash
cp .env.example .env
```

Local ports:

- API: <http://localhost:8080>
- React console: <http://localhost:5173>
- LocalStack: <http://localhost:4566>
- Postgres: `localhost:15432`
- Mock transfer agent: <http://localhost:8090>

## Local Runtime

```bash
make dev-up
make smoke
make smoke-failure-paths
make dev-down
```

`make dev-up` starts Postgres and LocalStack, initializes SNS/SQS resources, then starts the API, workers, mock transfer agent, and React console.

## Validation

```bash
make validate-tla
make validate-refinement
make validate-formal-coverage
make validate-specs
make validate-k8s
make validate-docs
make test
make validate
```

`make validate` runs TLA proofs/model checking, Rust-to-TLA mapping validation, specs, docs, Rust formatting, clippy, Rust tests, frontend install, frontend typecheck, lint, and tests.

## Kubernetes Demo

```bash
make k8s-up
make k8s-smoke
make k8s-down
```

The Kubernetes path uses kind and LocalStack inside the cluster. It does not require AWS credentials beyond local dummy values.
