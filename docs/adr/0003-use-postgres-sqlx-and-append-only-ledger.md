# ADR-0003: Use Postgres, SQLx, and an Append-Only Ledger

## Status
Accepted

## Context
Financial state requires durable transactions, precision constraints, idempotency, and auditable state transitions.

## Decision
Use Postgres with SQLx migrations. Ledger entries are append-only; corrections use compensating entries.

## Options Considered
- SQLite
- Postgres with SQLx
- Event store only

## Rationale
Postgres gives transactional guarantees and constraints that match institutional financial state better than an in-memory or file-only store.

## Consequences
Integration tests and local runtime require a Postgres service.

## Validation
Validated by SQL migrations, repository tests, append-only ledger code paths, and Docker Compose smoke scripts.
