---- MODULE YieldMessaging ----
EXTENDS YieldLifecycle

MessagingInvariantCatalog ==
  { "InboxDeduplicatesWorkerEffects",
    "OutboxRetryDoesNotDuplicateBusinessEffects" }

MessagingRuntimeMapping ==
  { "record_inbox_message",
    "lease_pending_outbox",
    "mark_published",
    "mark_failed" }

====
