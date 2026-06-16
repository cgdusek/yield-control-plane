# ADR-0005: Use Outbox, Inbox, and Idempotency for Resilient Messaging

## Status
Accepted

## Context
HTTP requests, database writes, SNS publishing, and SQS delivery can fail independently.

## Decision
Write outbox events in the same database transaction as business state. Workers record inbox messages before processing and use persisted idempotency records for external and HTTP commands.

## Options Considered
- Publish directly inside API requests
- Poll database without queue fanout
- Transactional outbox plus inbox deduplication

## Rationale
Outbox/inbox makes at-least-once delivery safe and keeps external side effects outside request transactions.

## Consequences
The system needs outbox publisher workers and cleanup/monitoring for stuck rows.

## Validation
Validated by persistence constraints, worker code, duplicate smoke tests, and runbooks for retry storms and DLQs.
