# Local Development

The primary development runtime is Docker Compose. It starts Postgres on host port `15432` to avoid conflicts with host Postgres on `5432`.

## Start

```bash
make check-tools
make dev-up
```

Local URLs:

- API: <http://localhost:8080>
- React console: <http://localhost:5173>
- LocalStack: <http://localhost:4566>
- Mock transfer agent: <http://localhost:8090>
- Postgres: `postgres://yield:yield@127.0.0.1:15432/yield_control`

## Smoke

```bash
make smoke
make smoke-failure-paths
```

`make smoke` creates a sweep order and waits until workers advance it to `Active`. `make smoke-failure-paths` checks rejected FIDD yield creation and the reconciliation break path.

## Reset

```bash
make dev-reset
make dev-up
```

`make dev-reset` removes Compose containers and volumes. Use it when database or LocalStack state should be rebuilt from migrations and queue initialization.

## Frontend

```bash
pnpm install
pnpm --filter institutional-yield-react-console dev
pnpm --filter institutional-yield-react-console test
pnpm --filter institutional-yield-react-console build
```

The Vite proxy target defaults to `http://localhost:8080` for host development. Docker and Kubernetes set `VITE_PROXY_TARGET=http://api:8080`.

## Kubernetes

```bash
./scripts/install-kind-tooling.sh
make k8s-up
make k8s-smoke
make k8s-down
```

The kind path loads locally built images and runs LocalStack inside the cluster. It does not use real AWS resources.

