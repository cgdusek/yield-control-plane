# ADR-0004: Enforce the State Machine in the Domain Layer

## Status
Accepted

## Context
Direct order lifecycle mutation would bypass financial safety rules and make worker retries unsafe.

## Decision
All status changes must call `transition(current, command, ctx)` in the domain crate. Repositories record the transition outcome rather than accepting arbitrary statuses.

## Options Considered
- Database-only status checks
- Service-local transition logic
- Shared domain transition function

## Rationale
A shared transition function centralizes guards, emitted events, and audit metadata.

## Consequences
All services that change lifecycle state must depend on the domain crate.

## Validation
Validated by the YAML machine, domain conformance tests, invalid-transition tests, API tests, worker tests, and command handler structure.
