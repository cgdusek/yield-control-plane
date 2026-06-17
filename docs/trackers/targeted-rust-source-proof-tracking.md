# Targeted Rust Source Proof Tracking

Status: complete
Last Updated: 2026-06-17T04:31:28Z

## Current Phase
Closed - targeted Rust source-proof rung passed and is represented in the repo surface coverage map.

## Live Checklist
| Item | Status | Evidence |
| --- | --- | --- |
| Tracker opened | complete | `AGENT_TRACKER.md` |
| Planning docs created | complete | `docs/trackers/targeted-rust-source-proof-*.md` |
| Kani harness added | complete | `crates/domain/src/sweep.rs` |
| Source proof validation passed | complete | `make validate-source-proofs` |
| JSON maps regenerated | complete | `make generate-repo-surface-coverage-map` |
| Full gate passed | complete | `make validate` |

## Phase Log
| Phase | Status | Notes |
| --- | --- | --- |
| P1 | complete | Kani source-proof harness verifies 6 bounded domain obligations. |
| P2 | complete | Repo surface map has `source_level_proof` axis and closed `rust_domain_core` evidence. |
| P3 | complete | Full validation passed after the `DomainEvent` clone cleanup. |

## Command Log
| Command | Result | Notes |
| --- | --- | --- |
| `cargo kani --version` | failed | Kani is not installed locally. |
| `cargo install --locked kani-verifier` | passed | Installed `kani-verifier v0.67.0`. |
| `cargo kani setup` | passed | Installed the Kani release bundle and pinned nightly toolchain. |
| `cargo kani -p institutional-yield-domain --harness accepted_transitions_never_stutter_and_preserve_source_command` | interrupted then passed | Initial string/iterator proof shapes were too broad; typed guard refactor fixed the harness. |
| `cargo kani -p institutional-yield-domain` | passed | 6 successfully verified harnesses, 0 failures. |
| `make validate-source-proofs` | passed | Source-proof gate invokes Kani through the repo validation path. |
| `make generate-repo-surface-coverage-map` | passed | Regenerated `spec/refinement/repo_surface_coverage_map.json`. |
| `make validate-repo-surface-coverage-map` | passed | Generated surface map is current and all surfaces remain closed. |
| `make validate` | failed then passed | First rerun failed on stale persistence clone after `DomainEvent` became `Copy`; final rerun passed. |

## Files Changed
- `AGENT_TRACKER.md`
- `docs/trackers/targeted-rust-source-proof-planning.md`
- `docs/trackers/targeted-rust-source-proof-implementation.md`
- `docs/trackers/targeted-rust-source-proof-tracking.md`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/validate-all.sh`
- `scripts/validate-source-proofs.sh`
- `scripts/generate-repo-surface-coverage-map.py`
- `spec/refinement/repo_surface_coverage_map.json`
- `crates/domain/src/sweep.rs`
- `docs/formal-verification.md`
- `docs/testing.md`
- `README.md`

## Boundary Audit
The round targets bounded source-level proof for the finite Rust transition kernel only.

## Validation Results
- `make validate-source-proofs` passed with 6 Kani harnesses and 0 failures.
- `make validate-repo-surface-coverage-map` passed after regenerating the JSON surface map.
- Full `make validate` passed after the persistence clone cleanup.

## Audit Closure
Closed. The source-level proof claim is intentionally narrow: Kani checks the finite domain transition kernel, while the repository-level map still rejects any claim that all Rust source lines are theorem-prover verified.

## Known Follow-Ups
Evaluate additional narrow Kani/Verus/Creusot proof targets after this rung passes.
