---- MODULE YieldProofs ----
EXTENDS YieldInvariants, TLAPS

THEOREM InitImpliesInv ==
  Init => Inv
PROOF
  BY SMT
     DEF Init,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM CreateOrderPreservesInv ==
  \A o \in Orders,
     a \in Accounts,
     k \in IdempotencyKeys,
     c \in CorrelationIds,
     p \in Assets,
     e \in EventIds :
    Inv /\ CreateOrder(o, a, k, c, p, e) => Inv'
PROOF
  BY SMT
     DEF CreateOrder,
         AddSeen,
         NonFiddAsset,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM MovePreservesInv ==
  \A o \in Orders, from \in StatusSet, to \in StatusSet, e \in EventIds :
    /\ Inv
    /\ to \notin {Active, CashCredited}
    /\ Move(o, from, to, e)
    => Inv'
PROOF
  BY SMT
     DEF Move,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedLedger,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM CheckEligibilityPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ CheckEligibility(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF CheckEligibility, StatusSet, Created, EligibilityChecked, Active, CashCredited

THEOREM CheckDisclosuresPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ CheckDisclosures(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF CheckDisclosures, StatusSet, EligibilityChecked, DisclosureChecked, Active, CashCredited

THEOREM ApprovePreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ Approve(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF Approve, StatusSet, DisclosureChecked, Approved, Active, CashCredited

THEOREM SubmitSubscriptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ SubmitSubscription(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF SubmitSubscription, StatusSet, CashLocked, SubscriptionSubmitted, Active, CashCredited

THEOREM ObserveChainMirrorPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ ObserveChainMirror(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF ObserveChainMirror, StatusSet, TransferAgentConfirmed, ChainMirrorObserved, Active, CashCredited

THEOREM ReconcilePreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ Reconcile(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF Reconcile, StatusSet, PositionBooked, Reconciled, Active, CashCredited

THEOREM ActivatePreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ Activate(o, e) => Inv'
PROOF
  BY SMT
     DEF Activate,
         Move,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedLedger,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM RequestRedemptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ RequestRedemption(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF RequestRedemption, StatusSet, Active, RedemptionRequested, CashCredited

THEOREM ReserveSharesPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ ReserveShares(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF ReserveShares, StatusSet, RedemptionRequested, SharesReserved, Active, CashCredited

THEOREM SubmitRedemptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ SubmitRedemption(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF SubmitRedemption, StatusSet, SharesReserved, RedemptionSubmitted, Active, CashCredited

THEOREM SettleRedemptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ SettleRedemption(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF SettleRedemption, StatusSet, CashCredited, Settled, Active

THEOREM CancelPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ Cancel(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF Cancel,
         StatusSet,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         Cancelled,
         Active,
         CashCredited

THEOREM CloseExceptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ CloseException(o, e) => Inv'
PROOF
  BY MovePreservesInv
     DEF CloseException, StatusSet, ExceptionOpen, ExceptionClosed, Active, CashCredited

THEOREM OpenExceptionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ OpenException(o, e) => Inv'
PROOF
  BY SMT
     DEF OpenException,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedLedger,
         UnchangedInboxEffects,
         UnchangedPositions,
         TerminalStatuses,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM LockCashPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ LockCash(o, e) => Inv'
PROOF
  BY SMT
     DEF LockCash,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM ConfirmTransferAgentPreservesInv ==
  \A o \in Orders, conf \in Confirmations, e \in EventIds :
    Inv /\ ConfirmTransferAgent(o, conf, e) => Inv'
PROOF
  BY SMT
     DEF ConfirmTransferAgent,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedLedger,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM BookPositionPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ BookPosition(o, e) => Inv'
PROOF
  BY SMT
     DEF BookPosition,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedInboxEffects,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM ConfirmRedemptionPreservesInv ==
  \A o \in Orders, conf \in Confirmations, e \in EventIds :
    Inv /\ ConfirmRedemption(o, conf, e) => Inv'
PROOF
  BY SMT
     DEF ConfirmRedemption,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedLedger,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM CreditCashPreservesInv ==
  \A o \in Orders, e \in EventIds :
    Inv /\ CreditCash(o, e) => Inv'
PROOF
  BY SMT
     DEF CreditCash,
         AddSeen,
         UnchangedOrderMetadata,
         UnchangedConfirmations,
         UnchangedInboxEffects,
         UnchangedPositions,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM LeaseOutboxPreservesInv ==
  \A e \in EventIds :
    Inv /\ LeaseOutbox(e) => Inv'
PROOF
  BY SMT
     DEF LeaseOutbox,
         vars,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM PublishOutboxPreservesInv ==
  \A e \in EventIds :
    Inv /\ PublishOutbox(e) => Inv'
PROOF
  BY SMT
     DEF PublishOutbox,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM ReceiveMessagePreservesInv ==
  \A c \in Consumers, m \in MessageIds :
    Inv /\ ReceiveMessage(c, m) => Inv'
PROOF
  BY SMT
     DEF ReceiveMessage,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM ProcessMessagePreservesInv ==
  \A c \in Consumers, m \in MessageIds :
    Inv /\ ProcessMessage(c, m) => Inv'
PROOF
  BY SMT
     DEF ProcessMessage,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM DeleteMessagePreservesInv ==
  \A c \in Consumers, m \in MessageIds :
    Inv /\ DeleteMessage(c, m) => Inv'
PROOF
  BY SMT
     DEF DeleteMessage,
         vars,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM CreateOrderAppendOnly ==
  \A o, a, k, c, p, e :
    CreateOrder(o, a, k, c, p, e) => LedgerAppendOnly
PROOF
  BY SMT DEF CreateOrder, LedgerAppendOnly

THEOREM MoveAppendOnly ==
  \A o, from, to, e :
    Move(o, from, to, e) => LedgerAppendOnly
PROOF
  BY SMT DEF Move, UnchangedLedger, LedgerAppendOnly

THEOREM LockCashAppendOnly ==
  \A o, e :
    LockCash(o, e) => LedgerAppendOnly
PROOF
  BY SMT DEF LockCash, LedgerAppendOnly

THEOREM ConfirmTransferAgentAppendOnly ==
  \A o, conf, e :
    ConfirmTransferAgent(o, conf, e) => LedgerAppendOnly
PROOF
  BY SMT DEF ConfirmTransferAgent, UnchangedLedger, LedgerAppendOnly

THEOREM BookPositionAppendOnly ==
  \A o, e :
    BookPosition(o, e) => LedgerAppendOnly
PROOF
  BY SMT DEF BookPosition, LedgerAppendOnly

THEOREM ConfirmRedemptionAppendOnly ==
  \A o, conf, e :
    ConfirmRedemption(o, conf, e) => LedgerAppendOnly
PROOF
  BY SMT DEF ConfirmRedemption, UnchangedLedger, LedgerAppendOnly

THEOREM CreditCashAppendOnly ==
  \A o, e :
    CreditCash(o, e) => LedgerAppendOnly
PROOF
  BY SMT DEF CreditCash, LedgerAppendOnly

THEOREM OpenExceptionAppendOnly ==
  \A o, e :
    OpenException(o, e) => LedgerAppendOnly
PROOF
  BY SMT DEF OpenException, UnchangedLedger, LedgerAppendOnly

THEOREM LeaseOutboxAppendOnly ==
  \A e :
    LeaseOutbox(e) => LedgerAppendOnly
PROOF
  BY SMT DEF LeaseOutbox, vars, LedgerAppendOnly

THEOREM PublishOutboxAppendOnly ==
  \A e :
    PublishOutbox(e) => LedgerAppendOnly
PROOF
  BY SMT DEF PublishOutbox, LedgerAppendOnly

THEOREM ReceiveMessageAppendOnly ==
  \A c, m :
    ReceiveMessage(c, m) => LedgerAppendOnly
PROOF
  BY SMT DEF ReceiveMessage, LedgerAppendOnly

THEOREM ProcessMessageAppendOnly ==
  \A c, m :
    ProcessMessage(c, m) => LedgerAppendOnly
PROOF
  BY SMT DEF ProcessMessage, LedgerAppendOnly

THEOREM DeleteMessageAppendOnly ==
  \A c, m :
    DeleteMessage(c, m) => LedgerAppendOnly
PROOF
  BY SMT DEF DeleteMessage, vars, LedgerAppendOnly

THEOREM LedgerAppendOnlyPreserved ==
  Next => LedgerAppendOnly
PROOF
  BY CreateOrderAppendOnly,
     MoveAppendOnly,
     LockCashAppendOnly,
     ConfirmTransferAgentAppendOnly,
     BookPositionAppendOnly,
     ConfirmRedemptionAppendOnly,
     CreditCashAppendOnly,
     OpenExceptionAppendOnly,
     LeaseOutboxAppendOnly,
     PublishOutboxAppendOnly,
     ReceiveMessageAppendOnly,
     ProcessMessageAppendOnly,
     DeleteMessageAppendOnly
     DEF Next,
         CheckEligibility,
         CheckDisclosures,
         Approve,
         SubmitSubscription,
         ObserveChainMirror,
         Reconcile,
         Activate,
         RequestRedemption,
         ReserveShares,
         SubmitRedemption,
         SettleRedemption,
         Cancel,
         CloseException

THEOREM NextPreservesInv ==
  Inv /\ Next => Inv'
PROOF
  BY CreateOrderPreservesInv,
     CheckEligibilityPreservesInv,
     CheckDisclosuresPreservesInv,
     ApprovePreservesInv,
     LockCashPreservesInv,
     SubmitSubscriptionPreservesInv,
     ConfirmTransferAgentPreservesInv,
     ObserveChainMirrorPreservesInv,
     BookPositionPreservesInv,
     ReconcilePreservesInv,
     ActivatePreservesInv,
     RequestRedemptionPreservesInv,
     ReserveSharesPreservesInv,
     SubmitRedemptionPreservesInv,
     ConfirmRedemptionPreservesInv,
     CreditCashPreservesInv,
     SettleRedemptionPreservesInv,
     CancelPreservesInv,
     CloseExceptionPreservesInv,
     OpenExceptionPreservesInv,
     LeaseOutboxPreservesInv,
     PublishOutboxPreservesInv,
     ReceiveMessagePreservesInv,
     ProcessMessagePreservesInv,
     DeleteMessagePreservesInv
     DEF Next

THEOREM StutterPreservesInv ==
  Inv /\ UNCHANGED vars => Inv'
PROOF
  BY SMT
     DEF vars,
         Inv,
         TypeOK,
         LifecycleSafe,
         UniquenessSafe,
         LedgerSafe,
         MessagingSafe,
         MetadataSafe,
         NoDuplicateIdempotency,
         NoDuplicateConfirmation,
         OnePositionPerOrder,
         PositionBookedRequiresTransferAgentConfirmation,
         ActiveRequiresReconciledHistory,
         CashCreditedRequiresRedemptionConfirmationHistory,
         CurrentStatusInHistory,
         NoFiddYieldSource,
         LedgerBalancedPerAsset,
         InboxDeduplicatesWorkerEffects,
         OutboxRetryDoesNotDuplicateBusinessEffects,
         WriteCommandCarriesCorrelationAndIdempotency,
         CreatedOrder,
         StatusSet,
         ConfirmationRefs,
         InboxPairs,
         NoStatus,
         Created,
         EligibilityChecked,
         DisclosureChecked,
         Approved,
         CashLocked,
         SubscriptionSubmitted,
         TransferAgentConfirmed,
         ChainMirrorObserved,
         PositionBooked,
         Reconciled,
         Active,
         RedemptionRequested,
         SharesReserved,
         RedemptionSubmitted,
         RedemptionConfirmed,
         CashCredited,
         Settled,
         ExceptionOpen,
         ExceptionClosed,
         Cancelled,
         NoConfirmation

THEOREM NextOrStutterPreservesInv ==
  Inv /\ [Next]_vars => Inv'
PROOF
  BY NextPreservesInv, StutterPreservesInv DEF vars

THEOREM InvImpliesSafety ==
  Inv => Safety
PROOF
  BY DEF Inv, Safety

THEOREM SpecImpliesAlwaysSafety ==
  Spec => []Safety
PROOF
  BY InitImpliesInv,
     NextOrStutterPreservesInv,
     InvImpliesSafety,
     PTL
     DEF Spec

====
