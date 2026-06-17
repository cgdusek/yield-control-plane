# Liveness Verification

The liveness layer covers conditional progress properties for the abstract protocol and executable implementation evidence. These checks are bounded TLC model checks plus Rust/runtime tests. They are not universal progress proofs under arbitrary transfer-agent, queue, database, network, or operator failure.

TLAPS remains mandatory where the obligation is an inductive safety proof. The temporal fairness/eventuality properties below are model-checked with TLC, while each row also cites TLAPS-checked safety theorems from [YieldProofs.tla](../spec/tla/YieldProofs.tla) for the actions that make up the progress path. `make validate-liveness` fails if a row omits TLAPS feasibility metadata, cites a missing theorem, or labels a temporal claim infeasible for TLAPS without an explicit TLAPS/temporal/fairness reason.

Run the liveness gate with:

```bash
make validate-liveness
make validate-tla
```

`make validate-tla` parses [YieldLiveness.tla](../spec/tla/YieldLiveness.tla) and model-checks three fair specs:

- `LifecycleFairSpec` in [YieldLiveness.cfg](../spec/tla/YieldLiveness.cfg)
- `ExceptionFairSpec` in [YieldExceptionLiveness.cfg](../spec/tla/YieldExceptionLiveness.cfg)
- `MessagingFairSpec` in [YieldMessagingLiveness.cfg](../spec/tla/YieldMessagingLiveness.cfg)

The configs use `CHECK_DEADLOCK FALSE` because terminal states such as `Settled` and `ExceptionClosed` intentionally have no further progress action in the finite liveness models.

## Progress Claims

| Property | TLA property | Fair spec | Status | Implementation evidence |
| --- | --- | --- | --- | --- |
| Created orders progress to active or terminal | `CreatedEventuallyActiveOrTerminal` | `LifecycleFairSpec` | bounded-pass | `subscription_progress_reaches_active_under_happy_path_assumptions`, smoke active check |
| Active redemptions progress to settlement | `ActiveEventuallyRedeemedOrTerminal` | `LifecycleFairSpec` | bounded-pass | `redemption_progress_reaches_settled_under_confirmation_assumptions` |
| Resolved exceptions close | `OpenExceptionEventuallyClosedIfResolved` | `ExceptionFairSpec` | conditional | `exception_resolution_progress_reaches_exception_closed_if_operator_resolves`, reconciliation resolve route |
| Persistent mismatch opens an exception | `ReconciliationBreakEventuallyOpensException` | `ExceptionFairSpec` | conditional | reconciliation worker opens `OpenException`, failure-path smoke check |
| Outbox event eventually publishes or fails for retry | `OutboxEventEventuallyPublishedOrFailed` | `MessagingFairSpec` | conditional | outbox publisher, `failed_outbox_event_becomes_leasable_until_published` |
| Outbox lease does not stay stuck | `LeaseDoesNotStayStuck` | `MessagingFairSpec` | conditional | failed publish clears `leased_until`, retry lease test |
| Inbox message eventually processes or deduplicates | `InboxMessageEventuallyProcessedOrDeduplicated` | `MessagingFairSpec` | conditional | inbox primary key, `inbox_message_progresses_once_then_deduplicates`, worker retry/delete policy tests |

## Assumptions

The liveness matrix [liveness_coverage.yaml](../spec/refinement/liveness_coverage.yaml) records the assumptions for each property. The core assumptions are fair scheduling of enabled internal actions, eventual transfer-agent confirmation in the abstract lifecycle model, eventual redemption confirmation and cash credit in the abstract redemption model, eventual queue delivery in the messaging model, and eventual operator resolution for exception closure.

## TLAPS Feasibility

The temporal properties are classified as not directly TLAPS-feasible because they depend on fairness and eventual environment behavior. The feasible safety obligations are still machine-checked by TLAPS:

- `CreatedEventuallyActiveOrTerminal`: `CreateOrderPreservesInv`, `CheckEligibilityPreservesInv`, `CheckDisclosuresPreservesInv`, `ApprovePreservesInv`, `LockCashPreservesInv`, `SubmitSubscriptionPreservesInv`, `ConfirmTransferAgentPreservesInv`, `ObserveChainMirrorPreservesInv`, `BookPositionPreservesInv`, `ReconcilePreservesInv`, `ActivatePreservesInv`, `OpenExceptionPreservesInv`, `CancelPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `ActiveEventuallyRedeemedOrTerminal`: `RequestRedemptionPreservesInv`, `ReserveSharesPreservesInv`, `SubmitRedemptionPreservesInv`, `ConfirmRedemptionPreservesInv`, `CreditCashPreservesInv`, `SettleRedemptionPreservesInv`, `OpenExceptionPreservesInv`, `CancelPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `OpenExceptionEventuallyClosedIfResolved`: `OpenExceptionPreservesInv`, `CloseExceptionPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `ReconciliationBreakEventuallyOpensException`: `OpenExceptionPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `OutboxEventEventuallyPublishedOrFailed`: `LeaseOutboxPreservesInv`, `PublishOutboxPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `LeaseDoesNotStayStuck`: `LeaseOutboxPreservesInv`, `PublishOutboxPreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`
- `InboxMessageEventuallyProcessedOrDeduplicated`: `ReceiveMessagePreservesInv`, `ProcessMessagePreservesInv`, `DeleteMessagePreservesInv`, `NextPreservesInv`, `SpecImpliesAlwaysSafety`

The runtime evidence for inbox progress also covers consumer-loop resilience. Handler and inbox-recording failures are logged and retried without exiting the worker, while malformed poison messages are deleted after logging. This is checked by `handler_errors_are_retried_without_exiting_consumer_policy`, `inbox_recording_errors_are_retried`, and `malformed_messages_are_deleteable_poison_messages`.

## Drift Gate

```bash
make validate-liveness
```

The validator checks that every liveness property has:

- a TLA temporal property;
- a fair spec in `YieldLiveness.tla`;
- TLAPS feasibility metadata and theorem-backed safety proof evidence where mathematically feasible;
- a TLC config that checks the property under that fair spec;
- explicit assumptions;
- Rust or persistence test evidence;
- runtime enforcement evidence;
- smoke, runbook, or observable evidence;
- `make validate` wiring.
