# Formal Refinement Planning

Status: complete
Branch: `main`
Base: local repository state on 2026-06-17

## Objective

Harden the formal verification spine from an abstract safety-guarded protocol toward Rust-to-TLA refinement evidence.

## Source Prompt Digest

The user requested exhaustive execution of the Rust-to-TLA refinement plan and recursive hardening loop. The implementation target is raw-action TLAPS preservation, executable Rust abstraction mapping, trace-refinement checks, and CI-enforced validation.

## Authority And Non-Goals

This remains a local engineering demo. The work must not imply production readiness, regulatory compliance, legal advice, investment advice, tax advice, accounting advice, or FIDD yield. A full Rust source refinement proof is not claimed unless a source-level verifier proves it.

## Boundary Rules

- No real AWS calls.
- No secrets or production account material.
- No direct order status mutation outside domain transitions.
- Generated verifier artifacts must be ignored or cleaned.
- Result statuses must distinguish `verified`, `bounded-pass`, `inconclusive`, and `out-of-scope`.

## Domain Skills Required

- `tracked-implementation-audit-loop`
- `formal-audit-proof-ladder`

## Phase Map

| Phase | Scope | Status |
| --- | --- | --- |
| F0 | Tracker and proof boundary refresh | complete |
| F1 | De-circularize TLA actions and TLAPS proof obligations | complete |
| F2 | Add Rust abstract model and trace refinement checks | complete |
| F3 | Add mapping validator and CI gate integration | complete |
| F4 | Run validation and close evidence | complete |
| F5 | Add invariant-level coverage matrix and drift gate | complete |
| F6 | Add exhaustive transition projection and TLA action proof coverage checks | complete |

## Dependency And Artifact Policy

Use existing Rust, proptest, TLAPS, and TLC tooling. Kani may be attempted only if it can be installed and run without destabilizing the local gate; otherwise record it as an explicitly bounded follow-up.

## Validation Strategy

```bash
make validate-tla
make validate-formal-coverage
cargo test -p institutional-yield-domain --all-features
make validate-refinement
make validate
```

## Audit Strategy

Every proof claim must map to a file and command. TLAPS results may be reported as `verified`; bounded property tests and trace checks are reported as `bounded-pass`.

## Handoff Criteria

The new gates pass, the tracker records command evidence, and docs describe the exact proof boundary.
