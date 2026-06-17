# Formal Liveness Planning

Status: complete
Branch: `main`
Base: pushed baseline `d288365`

## Objective

Add executable conditional liveness coverage for lifecycle progress, redemption progress, exception resolution, outbox publish progress, and inbox worker progress.

## Source Prompt Digest

The user requested execution of the formal liveness coverage plan using the implementation and formal loop skills until all gates pass.

## Authority And Non-Goals

This work is a local engineering verification artifact. It does not imply production readiness, regulatory compliance, legal advice, investment advice, tax advice, accounting advice, or FIDD yield. Liveness is conditional on explicit fairness and external-environment assumptions unless a checker proves a stronger claim.

## Boundary Rules

- No real AWS calls.
- No secrets or production account material.
- No direct order status mutation outside domain transitions.
- No universal liveness claim under arbitrary transfer-agent, queue, database, network, or operator failure.
- TLC liveness results are `bounded-pass`; Rust and smoke evidence are implementation conformance evidence, not full source-level temporal proof.

## Domain Skills Required

- `tracked-implementation-audit-loop`
- `formal-audit-proof-ladder`
- `coverage-convergence-loop`

## Phase Map

| Phase | Scope | Status |
| --- | --- | --- |
| L0 | Tracker and proof boundary refresh | complete |
| L1 | TLA liveness spec and TLC configs | complete |
| L2 | Rust and persistence progress tests | complete |
| L3 | Liveness coverage matrix and validator | complete |
| L4 | Docs and gate integration | complete |
| L5 | Full validation and closure | complete |

## Dependency And Artifact Policy

Use existing TLA tools, TLAPS installation, TLC, Rust tests, and validator style. New artifacts must be bound to `make validate-liveness`, `make validate-tla`, `make validate`, or a tracked runtime test path.

## Validation Strategy

```bash
make validate-liveness
make validate-tla
cargo test -p institutional-yield-domain --test liveness_trace_tests
cargo test -p institutional-yield-persistence --all-features
make validate-docs
make validate
```

## Audit Strategy

Every liveness property must have a TLA temporal formula, fairness assumptions, TLAPS feasibility metadata with theorem evidence where safety proof is feasible, bounded TLC config, Rust/runtime evidence, and drift validation. Results must be classified as `bounded-pass` or `conditional`, not unbounded temporal proof.

## Handoff Criteria

The liveness validator, TLC liveness configs, Rust tests, docs, and full static gate pass with no generated `.tlacache` or `states` directory left behind.
