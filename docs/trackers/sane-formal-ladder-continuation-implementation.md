# Sane Formal Ladder Continuation Implementation

Status: complete

## Work Breakdown
| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| R2 | Add Kani proofs for Rust-to-TLA mapping | `crates/domain/src/abstract_refinement.rs` | complete |
| R3 | Add built-in asset classifier proof and make source-proof coverage dynamic | `crates/domain/src/asset.rs`, `scripts/generate-repo-surface-coverage-map.py`, `spec/refinement/repo_surface_coverage_map.json` | complete |
| R4 | Document remaining ladder boundary | tracker docs, formal docs, `AGENT_TRACKER.md` | complete |

## Edit Plan
- Extract a pure action-mapping helper from `TlaAction::for_outcome`.
- Add Kani harnesses that prove mapped triples preserve command/action agreement and safety-relevant action bounds.
- Count Kani harnesses from source files in the generated repo surface map.
- Add a narrow built-in asset classifier proof for the FIDD yield-source boundary.
- Record why the next surfaces are better covered by existing layers instead of forced source-level proof.

## Generated Artifact Plan
- Regenerate `spec/refinement/repo_surface_coverage_map.json` after generator or tracker changes.

## Gate Integration Plan
The existing `make validate-source-proofs` target runs `cargo kani -p institutional-yield-domain` and will pick up the new harnesses automatically.

## Risk Register
| Risk | Mitigation |
| --- | --- |
| Kani explores heap-heavy refinement state | Prove the pure mapping helper, not `HashSet`-backed state replay. |
| Coverage accounting drifts | Derive harness count from `#[kani::proof]` markers. |
| Ladder overclaim | Keep full line-level proof ratio at `0.0` and record non-sane boundaries. |

## Decisions
- R2 targets Rust-to-TLA action mapping because it is central to refinement and finite enough for Kani.
- R3 adds built-in asset classifier proofs because `NoFiddYieldSource` is safety-significant and finite for built-in assets.
- Remaining Rust surfaces are not forced into Kani because their guarantees are already checked at stronger suited boundaries: TLAPS/TLC, SQL constraints, DB-backed tests, API tests, worker tests, smoke gates, and coverage drift validators.

## Deferred Items
None. Remaining Rust surfaces are not deferred source-proof tasks; they are explicitly classified in the generated JSON as better covered by SQL constraints, Rust tests, TLAPS/TLC, smoke gates, and drift validators for this repo state.

## Validation
- `make validate-source-proofs` passed with 14 Kani harnesses and 0 failures.
- `make validate-repo-surface-coverage-map` passed with 14/14 named source-proof obligations closed.
- `make validate` passed after the new rungs and boundary accounting were added.
