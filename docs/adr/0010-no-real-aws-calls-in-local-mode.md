# ADR-0010: Block Real AWS Calls in Local Mode

## Status
Accepted

## Context
The source specification prohibits real AWS resources and requires all local AWS SDK clients to default to LocalStack.

## Decision
Local config requires an explicit LocalStack endpoint for SNS/SQS clients and rejects AWS SDK setup that would target real AWS in local mode.

## Options Considered
- Use default AWS provider chain
- Require LocalStack endpoint in local mode
- Replace AWS SDK with in-memory queues

## Rationale
Using the AWS SDK with endpoint enforcement tests the real client shape while preventing accidental cloud calls.

## Consequences
Local messaging fails fast if endpoint configuration is missing or not local.

## Validation
Validated by config tests, messaging client construction tests, `.env.example`, `docs/security.md`, and smoke scripts.
