---- MODULE YieldInvariants ----
EXTENDS YieldLedger, YieldMessaging

InvariantCatalog ==
  { "NoDuplicateIdempotency",
    "NoDuplicateConfirmation",
    "OnePositionPerOrder",
    "PositionBookedRequiresTransferAgentConfirmation",
    "ActiveRequiresReconciledHistory",
    "CashCreditedRequiresRedemptionConfirmationHistory",
    "CurrentStatusInHistory",
    "NoFiddYieldSource",
    "LedgerBalancedPerAsset",
    "LedgerAppendOnly",
    "InboxDeduplicatesWorkerEffects",
    "OutboxRetryDoesNotDuplicateBusinessEffects",
    "WriteCommandCarriesCorrelationAndIdempotency" }

====
