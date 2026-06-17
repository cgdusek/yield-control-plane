# Institutional Yield Control Plane

A local, production-shaped simulation of an institutional DeFi yield control plane. It uses Rust services, Postgres, LocalStack SNS/SQS, Docker Compose, Kubernetes manifests, and a React/TypeScript operator console.

This repository is a local engineering demo. It is not legal, investment, accounting, tax, regulatory, or production deployment advice. FIDD is modeled as a cash/payment rail; FIDD balances do not themselves earn yield.

## Quickstart

```bash
make check-tools
make dev-up
make smoke
make smoke-failure-paths
```

Local URLs:

- API: <http://localhost:8080>
- React console: <http://localhost:5173>
- LocalStack: <http://localhost:4566>
- Mock transfer agent: <http://localhost:8090>
- Postgres: `localhost:15432`

## Specs

- OpenAPI: [spec/openapi.yaml](spec/openapi.yaml)
- AsyncAPI: [spec/asyncapi.yaml](spec/asyncapi.yaml)
- State machine: [spec/domain/sweep_order.machine.yaml](spec/domain/sweep_order.machine.yaml)
- Formal verification: [docs/formal-verification.md](docs/formal-verification.md)
- Liveness verification: [docs/liveness-verification.md](docs/liveness-verification.md)
- Source request: [spec/source/fidelity_defi_yield_platform_spec.md](spec/source/fidelity_defi_yield_platform_spec.md)

## Validation

```bash
make validate-tla
make validate-refinement
make validate-formal-coverage
make validate-liveness
make validate-specs
make validate-k8s
make validate-docs
make test
make validate
```

## Documentation

Start with [docs/index.md](docs/index.md). Architecture decisions live in [docs/adr/README.md](docs/adr/README.md), and agent handoff material starts at [docs/agentic/index.md](docs/agentic/index.md).
