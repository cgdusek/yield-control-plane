---- MODULE YieldLedger ----
EXTENDS YieldLifecycle

LedgerInvariantCatalog ==
  { "LedgerBalancedPerAsset", "LedgerAppendOnly" }

LedgerRuntimeMapping ==
  { "insert_balanced_ledger_entries",
    "validate_ledger_balances",
    "ledger_entries_no_update" }

====
