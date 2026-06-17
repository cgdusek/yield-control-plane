# Targeted Rust Source Proof Planning

Status: complete
Branch: `main`
Base: `origin/main`

## Objective
Add a targeted source-level proof rung for the Rust domain transition kernel and bind it to the generated JSON coverage maps and validation gates.

## Source Prompt Digest
The user wants to climb the sane verification ladder: keep the abstract TLAPS/TLC protocol proof, then add selective source-level proof where implementation bugs could bypass the formal boundary.

## Authority And Non-Goals
- Do not claim full source-line theorem-prover verification of the whole repository.
- Do not claim production, legal, regulatory, investment, accounting, or tax assurance.
- Do not claim FIDD balances earn yield.
- Do not weaken the existing TLAPS/TLC, Rust, SQL, smoke, or CI gates.

## Boundary Rules
- First source-proof target: `crates/domain/src/sweep.rs` transition decision table.
- Checker: Kani bounded model checking for finite `SweepStatus`, `SweepCommand`, and guard combinations.
- Coverage claim: bounded source-level proof for the finite transition kernel, not for all Rust services or async runtime behavior.

## Domain Skills Required
- `tracked-implementation-audit-loop`
- `coverage-convergence-loop`
- `formal-audit-proof-ladder`

## Phase Map
| Phase | Scope | Status |
| --- | --- | --- |
| P1 | Source-proof harness and Kani target | complete |
| P2 | Validation and JSON coverage integration | complete |
| P3 | Final gate and closure | complete |

## Dependency And Artifact Policy
Kani may be installed locally as a development verifier. The repository should not rely on generated verifier caches or local bytecode artifacts.

## Validation Strategy
Run `make validate-source-proofs`, `make validate-repo-surface-coverage-map`, `make validate-formal-coverage-map`, and `make validate`.

Current source-proof target: six Kani harnesses under `cfg(kani)` in `crates/domain/src/sweep.rs` covering accepted-transition shape, activation source, cash-credit source, position-booking guards, cancellation bounds, and exception-opening bounds.

## Audit Strategy
The JSON maps must record the new proof rung and still expose any remaining source-level proof gaps without overclaiming.

## Handoff Criteria
The source-proof harness passes, the generated maps are current, docs validate, and the full validation gate passes.

## Closure Evidence
- `make validate-source-proofs` passed with 6 Kani harnesses and 0 failures.
- `make validate` passed after the persistence `DomainEvent` clone cleanup.
- `spec/refinement/repo_surface_coverage_map.json` records `rust_domain_core` with a closed `source_level_proof` axis and keeps the full line-level Rust proof ratio at `0.0`.
