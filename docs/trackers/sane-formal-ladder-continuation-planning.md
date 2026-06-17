# Sane Formal Ladder Continuation Planning

Status: complete
Branch: `main`
Base: `origin/main`

## Objective
Continue the formal verification ladder beyond the domain transition Kani rung by adding the next bounded source-proof rungs that are mathematically useful and operationally maintainable.

## Source Prompt Digest
The user asked to climb the next rung, then continue until the ladder is complete. Completion means all sane in-scope rungs are either implemented and gated or explicitly bounded as non-sane for this repository state.

## Authority And Non-Goals
- Do not claim full source-line theorem-prover verification of all Rust, SQL, TypeScript, shell, YAML, Docker, Kubernetes, or Markdown.
- Do not weaken the existing TLAPS/TLC, Kani, Rust, SQL, smoke, or CI gates.
- Do not claim production, regulatory, legal, accounting, tax, investment, or deployment assurance.
- Do not claim FIDD balances earn yield.

## Boundary Rules
- Prefer pure finite kernels for Kani.
- Keep heap-heavy, async, database, network, and frontend behavior covered by the existing suited layers unless a narrow pure helper can be extracted without distorting the code.
- Every new artifact must be executable, validated, enforced by a script or CI, or explicitly tracked as a bounded deferral.

## Domain Skills Required
- `tracked-implementation-audit-loop`
- `formal-audit-proof-ladder`
- `coverage-convergence-loop`

## Phase Map
| Phase | Scope | Status |
| --- | --- | --- |
| R2 | Rust-to-TLA mapping source proof | complete |
| R3 | Built-in asset proof and dynamic source-proof coverage accounting | complete |
| R4 | Boundary audit for remaining non-sane rungs | complete |

## Dependency And Artifact Policy
Reuse the installed Kani verifier and existing validation scripts. Do not add new theorem-prover stacks unless the current ladder exposes a narrow gap that Kani, TLAPS, TLC, property tests, and runtime gates cannot cover.

## Validation Strategy
Run `make validate-source-proofs`, `make validate-repo-surface-coverage-map`, `make validate-docs`, `cargo clippy --workspace --all-targets --all-features -- -D warnings`, and `make validate`.

## Audit Strategy
Record each rung as `closed`, `deferred`, or `out_of_scope` with evidence and non-claims. Prefer generated coverage accounting over manually edited counts.

## Handoff Criteria
The new source-proof rungs are machine checked, the JSON map is current, all changed docs validate, and the full validation gate passes.

## Current Boundary
Closed source-proof rungs: built-in asset classifier, sweep transition kernel, and Rust-to-TLA mapping kernel. Remaining Rust surfaces are tracked in the JSON boundary register as covered by other gates because their behavior depends on Postgres, async runtimes, AWS SDK/LocalStack, HTTP middleware, or observability integrations.

## Closure
The ladder is complete for the current repo state: 14/14 named Kani source-proof obligations are closed, the full validation gate passes, and no additional pure finite Rust helper remains that would materially increase rigor without distorting the implementation boundary.
