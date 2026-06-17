# Formal Verification

The formal layer models the control plane as an abstract TLA+ safety protocol. TLAPS checks that the raw abstract actions preserve the invariant, TLC explores bounded interleavings, and the implementation is tied back through Rust refinement tests, a static Rust-to-TLA mapping validator, Postgres constraints, smoke tests, and CI.

Run the formal gate with:

```bash
make validate-tla
make validate-source-proofs
make validate-refinement
make validate-formal-coverage
make validate-formal-coverage-map
make validate-repo-surface-coverage-map
```

`scripts/validate-tla.sh` downloads `tla2tools.jar` and installs TLAPS under ignored `tools/` paths when the local machine does not already provide them. It then runs SANY parsing, TLAPS proof checking, and TLC model checking.

## Proof Boundary

The TLA+ protocol uses raw lifecycle, ledger, and messaging actions in [YieldLifecycle.tla](../spec/tla/YieldLifecycle.tla). `Inv` includes `CurrentStatusInHistory` as an induction-strengthening invariant so historical safety claims such as active-after-reconciled and cash-credited-after-redemption-confirmed are proved from status history rather than inferred from the current status alone.

The repository now provides refinement-lite evidence: [rust_tla_mapping.yaml](../spec/refinement/rust_tla_mapping.yaml) maps each Rust `SweepCommand` to a TLA action and TLAPS theorem, [abstract_refinement.rs](../crates/domain/src/abstract_refinement.rs) projects accepted Rust transitions into abstract state, and `scripts/validate-refinement.sh` rejects drift across Rust enums, TLA `Next`, Rust `TlaAction`, and TLAPS theorem names. The refinement tests also load the YAML mapping, exercise declared paths against the Rust `transition(...)` function, and fail if any accepted Rust transition lacks mapping evidence.

[asset.rs](../crates/domain/src/asset.rs), [sweep.rs](../crates/domain/src/sweep.rs), and [abstract_refinement.rs](../crates/domain/src/abstract_refinement.rs) also carry targeted Kani source-proof harnesses under `cfg(kani)`. `make validate-source-proofs` runs `cargo kani -p institutional-yield-domain` and proves bounded source-level obligations over the finite built-in asset classifier, sweep status/command/guard transition kernel, and Rust-to-TLA action mapping kernel. This is source-level evidence for narrow pure domain decision tables; it is not a full line-by-line proof of all Rust services, async workers, SQL behavior, frontend code, shell scripts, or infrastructure.

[invariant_coverage.yaml](../spec/refinement/invariant_coverage.yaml) is the invariant-level convergence matrix. `scripts/validate-formal-coverage.sh` parses the matrix, TLA catalog, TLAPS theorems, TLC config, Rust tests, runtime enforcement files, and full validation script so an invariant cannot be marked covered without executable evidence.

[formal_coverage_map.json](../spec/refinement/formal_coverage_map.json) is the generated closure map for reviewing the current state. Refresh it with `make generate-formal-coverage-map`; verify it with `make validate-formal-coverage-map`. The map is derived from the invariant, liveness, and Rust-to-TLA matrices and records each item as `closed`, `closed_bounded`, `closed_under_assumptions`, or `needs_work` with concrete closure actions.

[repo_surface_coverage_map.json](../spec/refinement/repo_surface_coverage_map.json) is the generated integrated surface map. Refresh it with `make generate-repo-surface-coverage-map`; verify it with `make validate-repo-surface-coverage-map`. It assigns every tracked source file to one major surface and records the surface contract, code-level enforcement, formal relationship, validation gates, closure status, and hardening frontier. This is the control plane for deciding which surfaces to specify or enforce next.

## Formal Spine

- Types and finite model vocabulary: [YieldTypes.tla](../spec/tla/YieldTypes.tla)
- Lifecycle, ledger, messaging, and metadata safety predicates: [YieldLifecycle.tla](../spec/tla/YieldLifecycle.tla)
- Ledger catalog: [YieldLedger.tla](../spec/tla/YieldLedger.tla)
- Messaging catalog: [YieldMessaging.tla](../spec/tla/YieldMessaging.tla)
- Invariant catalog: [YieldInvariants.tla](../spec/tla/YieldInvariants.tla)
- TLAPS proof obligations: [YieldProofs.tla](../spec/tla/YieldProofs.tla)
- TLC bounded model: [YieldControlPlane.cfg](../spec/tla/YieldControlPlane.cfg)

## Invariant Traceability

| Invariant | TLA+ definition | TLAPS theorem | TLC model | Rust or SQL enforcement | CI gate |
| --- | --- | --- | --- | --- | --- |
| NoDuplicateIdempotency | `NoDuplicateIdempotency` | `CreateOrderPreservesInv`, `NextPreservesInv` | `INVARIANT Inv` | `unique (account_id, idempotency_key_hash)`, `duplicate_idempotency_key_reuses_order` | `make validate-tla`, DB tests |
| NoDuplicateConfirmation | `NoDuplicateConfirmation` | `ConfirmTransferAgentPreservesInv`, `NextPreservesInv` | `INVARIANT Inv` | `unique (transfer_agent_confirmation_ref)`, `duplicate_confirmation_ref_cannot_double_book` | `make validate-tla`, DB tests |
| OnePositionPerOrder | `OnePositionPerOrder` | `BookPositionPreservesInv` | `INVARIANT Inv` | `positions unique (order_id)` | `make validate-tla`, DB tests |
| PositionBookedRequiresTransferAgentConfirmation | `PositionBookedRequiresTransferAgentConfirmation` | `BookPositionPreservesInv` | `INVARIANT Safety` | `validate_position_booking_confirmation`, command side effects | `make validate-tla`, Rust tests |
| ActiveRequiresReconciledHistory | `ActiveRequiresReconciledHistory` | `ActivatePreservesInv` | `INVARIANT Safety` | `transition` from `Reconciled` to `Active`, property tests | `make validate-tla`, Rust tests |
| CashCreditedRequiresRedemptionConfirmationHistory | `CashCreditedRequiresRedemptionConfirmationHistory` | `CreditCashPreservesInv` | `INVARIANT Safety` | domain transition sequence and redemption confirmation guard | `make validate-tla`, Rust tests |
| CurrentStatusInHistory | `CurrentStatusInHistory` | `NextPreservesInv` | `INVARIANT Inv` | `AbstractSweepState`, refinement trace tests | `make validate-tla`, `make validate-refinement`, Rust tests |
| NoFiddYieldSource | `NoFiddYieldSource` | `CreateOrderPreservesInv` | `INVARIANT Safety` | `ensure_yield_source_allowed`, API rejection path | `make validate-tla`, Rust/API tests |
| LedgerBalancedPerAsset | `LedgerBalancedPerAsset` | `LockCashPreservesInv`, `BookPositionPreservesInv`, `CreditCashPreservesInv` | `INVARIANT Inv` | `insert_balanced_ledger_entries`, `validate_ledger_balances` | `make validate-tla`, Rust tests |
| LedgerAppendOnly | `LedgerAppendOnly` | `LedgerAppendOnlyPreserved` | `Spec` step safety | `ledger_entries_no_update` trigger | `make validate-tla`, DB tests |
| InboxDeduplicatesWorkerEffects | `InboxDeduplicatesWorkerEffects` | `ReceiveMessagePreservesInv`, `ProcessMessagePreservesInv` | `INVARIANT Inv` | `inbox_messages primary key`, `record_inbox_message` | `make validate-tla`, smoke tests |
| OutboxRetryDoesNotDuplicateBusinessEffects | `OutboxRetryDoesNotDuplicateBusinessEffects` | `LeaseOutboxPreservesInv`, `PublishOutboxPreservesInv` | `INVARIANT Inv` | outbox leasing and event-id primary key | `make validate-tla`, smoke tests |
| WriteCommandCarriesCorrelationAndIdempotency | `WriteCommandCarriesCorrelationAndIdempotency` | `CreateOrderPreservesInv` | `INVARIANT Safety` | OpenAPI parameters and API write-header middleware | `make validate-tla`, spec/API tests |

## Commands

```bash
make validate-tla
make validate-source-proofs
make validate-refinement
make validate-formal-coverage
make validate-formal-coverage-map
make validate-repo-surface-coverage-map
make validate
```

The full validation gate runs `scripts/validate-tla.sh`, `scripts/validate-source-proofs.sh`, `scripts/validate-refinement.sh`, `scripts/validate-formal-coverage.sh`, `scripts/validate-formal-coverage-map.sh`, and `scripts/validate-repo-surface-coverage-map.sh` before specs, Kubernetes manifests, docs, Rust, and frontend checks.
