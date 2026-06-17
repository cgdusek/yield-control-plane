# Formal Verification Implementation

Status: complete

## Work Breakdown

| Phase | Primary Files | Status |
| --- | --- | --- |
| TLA model | `spec/tla/Yield*.tla`, `spec/tla/YieldControlPlane.cfg` | complete |
| Proof gate | `scripts/validate-tla.sh`, `Makefile`, `scripts/validate-all.sh` | complete |
| CI and tools | `.github/workflows/ci.yml`, `.gitignore`, `scripts/check-tools.sh` | complete |
| Docs | `docs/formal-verification.md`, `docs/traceability.md`, `docs/testing.md` | complete |

## Decisions

- The abstract protocol uses `ActionSafe == Inv' /\ LedgerAppendOnly` as a post-state safety guard.
- TLC uses two orders and single-value account, idempotency, confirmation, event, consumer, and message domains to keep CI state exploration bounded.
- `scripts/validate-tla.sh` bootstraps TLAPS and TLA tools into ignored local paths when absent.

## Risk Register

| Risk | Handling |
| --- | --- |
| TLAPS is not a full temporal prover | Temporal scope is limited and documented; TLC checks bounded interleavings. |
| Formal model diverges from code | Traceability maps invariants to Rust tests, SQL constraints, and smoke gates. |
| Toolchain availability varies | Validator downloads supported macOS and Linux TLAPS release assets. |

## Deferred Items

No implementation items are deferred in this workstream. A full Rust-to-TLA refinement proof is outside the declared proof boundary.
