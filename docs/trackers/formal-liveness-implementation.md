# Formal Liveness Implementation

Status: complete

## Work Breakdown

| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| L1 | TLA liveness spec and TLC configs | `spec/tla/YieldLiveness.tla`, `spec/tla/*Liveness.cfg`, `scripts/validate-tla.sh` | complete |
| L2 | Rust and persistence progress tests | `crates/domain/tests/liveness_trace_tests.rs`, `crates/persistence/tests/repository_tests.rs` | complete |
| L3 | Coverage matrix and validator | `spec/refinement/liveness_coverage.yaml`, `scripts/validate-liveness-coverage.sh` | complete |
| L4 | Docs and gate wiring | `docs/liveness-verification.md`, `Makefile`, `scripts/validate-all.sh`, docs indexes | complete |
| L5 | Validation closure | `AGENT_TRACKER.md`, this tracker set | complete |

## Edit Plan

Add separate lifecycle, exception, and messaging fair specs so liveness checks do not conflate happy-path progress with exception or queue progress. Add tests and validators that bind those properties back to Rust transitions, outbox lease/retry, inbox dedupe, worker loops, smoke tests, CI, and TLAPS-backed safety proof evidence where the obligation is mathematically reducible to inductive safety.

## Generated Artifact Plan

TLC and TLAPS generated state remains ignored and is cleaned by validation scripts.

## Gate Integration Plan

Add `make validate-liveness` and run it from `scripts/validate-all.sh` after `validate-formal-coverage`.

## Risk Register

| Risk | Handling |
| --- | --- |
| TLC liveness state space grows too large | Use bounded configs with one account/idempotency key and separate lifecycle/messaging specs. |
| Fairness assumptions overclaim external behavior | Put external confirmations, queue delivery, publish availability, and operator action in the assumption register and validator. |
| Stuttering actions mask progress | Exclude non-progress stutter actions from fair progress specs or mark the property conditional. |
| Worker exits on one stale or poison message | Consumer loop logs per-message failures and continues; handler/inbox failures retry, malformed messages delete. |

## Decisions

- Use TLC for bounded liveness checks and keep TLAPS focused on safety.
- Require the liveness coverage validator to parse `YieldProofs.tla`; every progress property must cite supporting TLAPS safety theorems or, for direct temporal proof claims, cite checked TLAPS property theorems.
- Classify all liveness properties as `bounded-pass` plus `conditional` where external action is required.
- Treat per-message worker failure handling as part of inbox progress evidence because one crashing consumer can violate practical liveness even when the abstract queue model is fair.

## Deferred Items

None.
