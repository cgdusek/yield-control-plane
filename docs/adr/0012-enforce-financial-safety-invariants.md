# ADR-0012: Enforce Financial Safety Invariants in Domain and Persistence

## Status
Accepted

## Context
The source specification requires idempotent financial writes, no FIDD yield accrual, no position booking without confirmation, and append-only ledger behavior.

## Decision
Enforce safety invariants in both the Rust domain layer and persistence constraints where practical.

## Options Considered
- Application-only validation
- Database-only constraints
- Layered domain and persistence validation

## Rationale
Layering makes bugs easier to catch in tests and harder to trigger in local runtime.

## Consequences
Some rules are duplicated intentionally across code and schema constraints.

## Validation
Validated by domain tests, property tests, SQL unique/check constraints, persistence tests, and failure-path smoke scripts.
