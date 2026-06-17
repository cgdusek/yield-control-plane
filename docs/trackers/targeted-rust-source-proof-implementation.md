# Targeted Rust Source Proof Implementation

Status: complete

## Work Breakdown
| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| P1 | Add Kani source-proof harness | `crates/domain/src/sweep.rs`, `scripts/validate-source-proofs.sh` | in-progress |
| P1 | Add Kani source-proof harness | `crates/domain/src/sweep.rs`, `scripts/validate-source-proofs.sh` | complete |
| P2 | Add proof coverage axis | `scripts/generate-*.py`, `spec/refinement/*.json` | complete |
| P3 | Validate and close | `AGENT_TRACKER.md`, tracker docs | complete |

## Edit Plan
- Refactor transition metadata to make the same transition table suitable for verifier calls.
- Add Kani proof functions under `#[cfg(kani)]`.
- Add `make validate-source-proofs`.
- Add `source_level_proof` to the repository surface map.
- Install Kani in CI before `make validate`.

## Generated Artifact Plan
Regenerate:
- `spec/refinement/repo_surface_coverage_map.json`

## Gate Integration Plan
`scripts/validate-all.sh` must invoke the source-proof gate before Rust tests so CI fails on proof drift.

## Risk Register
| Risk | Mitigation |
| --- | --- |
| Kani rejects heap-heavy code | Target the pure transition decision table rather than service code. |
| Proof claim overreach | Keep JSON non-claim for full source-line proof. |
| CI environment lacks Kani | Install Kani in the workflow if validation is wired into `make validate`. |
| Kani explores irrelevant string or iterator internals | Use typed `Guard` and bounded `GuardSet` for the source-proof path. |

## Decisions
- Use Kani as the first practical source-level checker for the finite domain transition kernel.
- Keep public guard strings stable while using typed guards internally for finite proof obligations.

## Deferred Items
None.

## Closure Notes
- Kani source proof passes through `make validate-source-proofs`.
- CI installs Kani before `make validate`.
- Full validation passed after removing a stale `.clone()` call made invalid by `DomainEvent: Copy`.
