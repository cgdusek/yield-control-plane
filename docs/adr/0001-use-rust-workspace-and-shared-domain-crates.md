# ADR-0001: Use a Rust Workspace and Shared Domain Crates

## Status
Accepted

## Context
The system needs multiple deployable services that share financial domain rules without duplicating lifecycle logic.

## Decision
Use a Rust workspace with shared crates for domain, persistence, messaging, observability, and config, plus service crates for API, workers, and mock transfer agent.

## Options Considered
- Single Rust binary with modules
- Rust workspace with shared crates
- Polyglot services

## Rationale
A workspace keeps domain logic reusable while preserving independent service binaries for the local microservices shape.

## Consequences
Shared crates create clear boundaries, but workspace builds compile all shared dependencies during validation.

## Validation
Validated by `cargo fmt --all --check`, `cargo clippy --workspace --all-targets --all-features -- -D warnings`, `cargo test --workspace --all-features`, and CI.
