# Operations

This repository operates a local runtime, not production infrastructure. Operational procedures still use production-shaped checks: health endpoints, metrics, deterministic smoke tests, audit records, and runbooks.

## Health

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8090/health
```

The API readiness endpoint includes database connectivity. Compose and Kubernetes use the same health paths for service rollout.

## Metrics

```bash
curl -fsS http://localhost:8080/metrics
```

The current metrics endpoint exposes a lightweight service snapshot. It is intentionally local and plain text so it can be checked without a metrics backend.

## Audit Trail

```bash
curl -fsS http://localhost:8080/audit-events
```

State transitions insert audit events and timeline entries. Operator review should compare `/audit-events`, `/sweep-orders/{id}`, `/positions`, and `/reconciliation-breaks`.

## Runbooks

- [LocalStack SNS/SQS](runbooks/localstack-sns-sqs.md)
- [Postgres ledger integrity](runbooks/postgres-ledger-integrity.md)
- [Reconciliation breaks](runbooks/reconciliation-breaks.md)
- [Kubernetes kind](runbooks/kubernetes-kind.md)
- [Failure injection](runbooks/failure-injection.md)

