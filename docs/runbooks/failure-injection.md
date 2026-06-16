# Failure Injection

Failure injection is local-only and exposed under `/dev`.

## Enable Reconciliation Mismatch

```bash
curl -fsS -X POST http://localhost:8080/dev/failure-injections/reconciliation-mismatch \
  -H 'Idempotency-Key: enable-recon-mismatch' \
  -H 'Correlation-Id: local-failure-test' \
  -H 'Content-Type: application/json' \
  -d '{"enabled":true}'
```

## Run the Failure Smoke

```bash
make smoke-failure-paths
```

## Disable Reconciliation Mismatch

```bash
curl -fsS -X POST http://localhost:8080/dev/failure-injections/reconciliation-mismatch \
  -H 'Idempotency-Key: disable-recon-mismatch' \
  -H 'Correlation-Id: local-failure-test' \
  -H 'Content-Type: application/json' \
  -d '{"enabled":false}'
```

