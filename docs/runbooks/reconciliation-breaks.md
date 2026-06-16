# Reconciliation Breaks

## Create a Break Locally

```bash
make smoke-failure-paths
```

The script enables reconciliation mismatch injection, creates an order, waits for `Exception`, and verifies a reconciliation break exists.

## Inspect Breaks

```bash
curl -fsS http://localhost:8080/reconciliation-breaks
```

## Resolve a Break

Use the break ID returned by the API:

```bash
curl -fsS -X POST http://localhost:8080/reconciliation-breaks/<break-id>/resolve \
  -H 'Idempotency-Key: resolve-break-1' \
  -H 'Correlation-Id: local-runbook' \
  -H 'Content-Type: application/json' \
  -d '{"reason":"local operator reviewed and cleared the break"}'
```

Resolution does not bypass the state machine. It records operator disposition for the break.

