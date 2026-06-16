# ADR-0002: Use LocalStack for Local SNS/SQS

## Status
Accepted

## Context
The source specification requires SNS/SQS-style asynchronous fanout without using real AWS resources.

## Decision
Run LocalStack locally and create one SNS topic with worker SQS subscriptions and DLQs.

## Options Considered
- In-memory channels
- LocalStack SNS/SQS
- Real AWS SNS/SQS dev account

## Rationale
LocalStack exercises AWS SDK behavior and queue semantics without cloud calls.

## Consequences
The local runtime depends on Docker, and some AWS edge behavior remains simulated.

## Validation
Validated by `scripts/localstack-init.sh`, `docker-compose.yml`, messaging tests, smoke scripts, and ADR-0010 endpoint checks.
