# Formal Refinement Implementation

Status: complete

## Work Breakdown

| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| F1 | Raw TLA action proofs | `spec/tla/YieldLifecycle.tla`, `spec/tla/YieldProofs.tla` | complete |
| F2 | Rust abstract model | `crates/domain/src/abstract_refinement.rs`, domain tests | complete |
| F3 | Mapping validator | `spec/refinement/rust_tla_mapping.yaml`, `scripts/validate-refinement.sh` | complete |
| F4 | Docs and gates | `docs/formal-verification.md`, `Makefile`, validators | complete |
| F5 | Invariant coverage convergence | `spec/refinement/invariant_coverage.yaml`, `scripts/validate-formal-coverage.sh` | complete |
| F6 | Exhaustive refinement drift hardening | `crates/domain/tests/refinement_trace_tests.rs`, `scripts/validate-refinement.sh` | complete |

## Edit Plan

Remove `ActionSafe == Inv'` from action definitions. Add raw-action proof lemmas for each action class. Add Rust `AbstractState` and tests that project accepted domain transitions into TLA action names and invariant checks.

F6 adds two executable checks: every declared Rust transition in the mapping must be accepted by the Rust domain transition function and project to the mapped TLA action, and every non-wrapper action in TLA `Next` must have a same-named `PreservesInv` theorem.

## Generated Artifact Plan

No generated repository artifacts. TLAPS `.tlacache` and TLC state directories remain ignored and cleaned by scripts.

## Gate Integration Plan

Add `make validate-refinement` and `make validate-formal-coverage`; run both from `scripts/validate-all.sh` after `validate-tla`.

## Risk Register

| Risk | Handling |
| --- | --- |
| TLAPS cannot discharge some raw-action obligations | Decompose action classes and record any remaining source-level proof limitation explicitly. |
| Rust model becomes a duplicate implementation | Keep it minimal and bind it to tests and TLA mapping validation. |
| Kani install is unsupported on this host | Record as `inconclusive` or follow-up; do not block the enforceable property-test gate. |

## Decisions

- Use refinement-lite before attempting full source-level verification.
- Keep network/AWS/SQLx surfaces outside the pure Rust proof boundary.

## Deferred Items

No F5 implementation items are deferred.

No F6 implementation items are deferred.
