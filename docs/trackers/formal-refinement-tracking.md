# Formal Refinement Tracking

Status: complete
Last Updated: 2026-06-17T02:36:46Z

## Current Phase

Formal refinement hardening complete with exhaustive Rust transition projection and static TLA action proof coverage.

## Live Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| Gate opened | complete | `AGENT_TRACKER.md` updated |
| Raw TLA action proofs | complete | `make validate-tla` proved 131 obligations in `YieldProofs.tla`; TLC completed with no error |
| Rust abstract refinement tests | complete | `crates/domain/tests/refinement_trace_tests.rs`; `make validate` |
| Mapping validator | complete | `scripts/validate-refinement.sh`; `make validate-refinement` |
| Invariant coverage matrix | complete | `spec/refinement/invariant_coverage.yaml`; `make validate-formal-coverage` |
| Full validation | complete | `make validate` passed |
| Exhaustive Rust transition projection | complete | `crates/domain/tests/refinement_trace_tests.rs`; `cargo test -p institutional-yield-domain --test refinement_trace_tests`; `make validate` |
| Static TLA `Next` proof coverage | complete | `scripts/validate-refinement.sh`; `make validate-refinement`; `make validate` |

## Phase Log

| Phase | Status | Notes |
| --- | --- | --- |
| F0 | complete | Existing safety-guarded protocol inspected and tracker opened. |
| F1 | complete | Safety-guarded `ActionSafe` removed; raw action-preservation proof decomposition passes. |
| F5 | complete | Added a drift gate across TLA definition, TLAPS theorem, TLC, Rust tests, runtime enforcement, and CI axes. |
| F6 | complete | Exhaustive transition projection and proof-coverage drift checks added and validated. |

## Command Log

| Command | Result | Notes |
| --- | --- | --- |
| `git status --short` | passed | Existing formal-verification worktree changes are present. |
| `sed -n ...` | passed | Read tracker, TLA, and domain surfaces. |
| `make validate-tla` | failed | Raw-action TLAPS pass rejected `MovePreservesInv` and inherited wrapper obligations. |
| `make validate-tla` | passed | TLAPS proved 131 obligations in `YieldProofs.tla` and 1 in `no_double_sweep.tla`; TLC found no error. |
| `make validate-formal-coverage` | passed | Invariant coverage matrix matched TLA catalog, TLAPS theorems, TLC config, Rust tests, runtime enforcement, and validate-all wiring. |
| `make validate` | passed | Full static validation passed, including TLA, refinement, formal coverage, specs, k8s, docs, Rust, pnpm install, frontend typecheck/lint/tests. |
| `git status --short`; `sed -n ...`; `rg ...` | passed | F6 opened from existing formal-refinement worktree; no generated TLA state present at start. |
| `cargo test -p institutional-yield-domain --test refinement_trace_tests` | failed | New test used a hard-coded mapping path count of 35; actual mapping declares 38 paths. |
| `make validate-refinement` | passed | Static validator accepted TLA `Next` preservation coverage and Rust/TLA mapping consistency. |
| `cargo test -p institutional-yield-domain --test refinement_trace_tests` | passed | 9 refinement tests passed after deriving the expected declared path count from `rust_tla_mapping.yaml`. |
| `make validate-refinement` | passed | Validator passed after adding static TLA `Next` action preservation theorem coverage. |
| `cargo fmt --all --check` | failed | Rustfmt required wrapping one panic call in the new test. |
| `cargo fmt --all` | passed | Applied rustfmt formatting. |
| `make validate-tla` | passed | TLAPS proved 131 obligations in `YieldProofs.tla` and 1 in `no_double_sweep.tla`; TLC completed with 5,643 distinct states and no errors. |
| `make validate-formal-coverage` | passed | Coverage matrix still matches invariant catalog, proof, TLC, Rust, runtime, and CI evidence. |
| `make validate-docs` | passed | Docs and tracker links validated after F6 updates. |
| `make validate` | passed | Full static validation passed after F6 hardening. |
| `test ! -d .tlacache && test ! -d states` | passed | No generated TLAPS/TLC state remains. |

## Files Changed

`AGENT_TRACKER.md`, `docs/trackers/formal-refinement-*.md`, `spec/tla/YieldLifecycle.tla`, `spec/tla/YieldProofs.tla`.
`spec/refinement/invariant_coverage.yaml`, `scripts/validate-formal-coverage.sh`, `spec/tla/YieldControlPlane.cfg`, docs and gate wiring.

## Boundary Audit

No production, legal, regulatory, or source-level refinement claim is made at this phase.

## Validation Results

`make validate` passed after F6 hardening.

## Audit Closure

F6 complete. No generated `.tlacache` or `states` directory remains after validation.

## Known Follow-Ups

None.
