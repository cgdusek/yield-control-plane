# ADR-0007: Use Docker Compose for the Primary Local Runtime

## Status
Accepted

## Context
The full local workflow needs Postgres, LocalStack, API, workers, mock services, and web UI.

## Decision
Use Docker Compose as the primary one-command runtime.

## Options Considered
- Manual processes
- Docker Compose
- Kubernetes only

## Rationale
Compose is simpler for local development and gives deterministic service wiring before Kubernetes.

## Consequences
Local Docker is required for end-to-end smoke tests.

## Validation
Validated by `docker-compose.yml`, `make dev-up`, `make smoke`, `make smoke-failure-paths`, and `make dev-down`.
