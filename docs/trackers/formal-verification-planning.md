# Formal Verification Planning

Status: complete
Branch: `main`
Base: local repository state on 2026-06-17

## Objective

Add a formal verification spine that ties safety invariants to TLA+ definitions, TLAPS checked proof obligations, TLC bounded model checking, runtime enforcement, and CI.

## Source Prompt Digest

The requested shape is a regulated-market-grade demo: abstract formal safety spec, checked TLAPS proof, bounded TLC interleavings, Rust property tests, Postgres constraints, and CI traceability.

## Authority And Non-Goals

The repo remains a local engineering demo. It does not provide legal, investment, accounting, tax, regulatory, production deployment, or FIDD yield advice. The formal layer does not claim Rust-to-TLA refinement.

## Boundary Rules

No real AWS calls are made. Downloaded TLA tools live under ignored `tools/` paths. Generated TLAPS and TLC state is cleaned or ignored.

## Phase Map

| Phase | Scope | Status |
| --- | --- | --- |
| Formal model | Add TLA module spine and finite TLC config | complete |
| Proofs | Add TLAPS proof obligations for safety-preserving actions | complete |
| Gate integration | Add `scripts/validate-tla.sh`, `make validate-tla`, and CI Java setup | complete |
| Traceability | Add docs mapping invariants to proof, model, Rust, SQL, and CI | complete |

## Validation Strategy

```bash
make validate-tla
make validate-specs
make validate-docs
```

Full validation remains `make validate`.

## Handoff Criteria

The formal gate must pass locally, the docs must validate, and `AGENT_TRACKER.md` must record command evidence before final handoff.
