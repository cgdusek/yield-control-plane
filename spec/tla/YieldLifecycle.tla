---- MODULE YieldLifecycle ----
EXTENDS YieldTypes

VARIABLES
  status,
  account,
  idempotencyKey,
  correlationId,
  productAsset,
  confirmationRef,
  redemptionRef,
  positionBooked,
  seenStatuses,
  ledgerDebit,
  ledgerCredit,
  ledgerEntries,
  inboxSeen,
  workerEffects,
  outboxEvents,
  businessEffects

vars ==
  << status,
     account,
     idempotencyKey,
     correlationId,
     productAsset,
     confirmationRef,
     redemptionRef,
     positionBooked,
     seenStatuses,
     ledgerDebit,
     ledgerCredit,
     ledgerEntries,
     inboxSeen,
     workerEffects,
     outboxEvents,
     businessEffects >>

CreatedOrder(o) == status[o] # NoStatus

TypeOK ==
  /\ status \in [Orders -> StatusSet]
  /\ account \in [Orders -> Accounts]
  /\ idempotencyKey \in [Orders -> IdempotencyKeys]
  /\ correlationId \in [Orders -> CorrelationIds]
  /\ productAsset \in [Orders -> Assets]
  /\ confirmationRef \in [Orders -> ConfirmationRefs]
  /\ redemptionRef \in [Orders -> ConfirmationRefs]
  /\ positionBooked \subseteq Orders
  /\ seenStatuses \in [Orders -> SUBSET StatusSet]
  /\ ledgerDebit \in [Assets -> Nat]
  /\ ledgerCredit \in [Assets -> Nat]
  /\ ledgerEntries \subseteq Assets
  /\ inboxSeen \subseteq InboxPairs
  /\ workerEffects \subseteq InboxPairs
  /\ outboxEvents \subseteq EventIds
  /\ businessEffects \subseteq EventIds

NoDuplicateIdempotency ==
  \A o1, o2 \in Orders :
    /\ CreatedOrder(o1)
    /\ CreatedOrder(o2)
    /\ account[o1] = account[o2]
    /\ idempotencyKey[o1] = idempotencyKey[o2]
    => o1 = o2

NoDuplicateConfirmation ==
  \A o1, o2 \in Orders :
    /\ confirmationRef[o1] # NoConfirmation
    /\ confirmationRef[o1] = confirmationRef[o2]
    => o1 = o2

OnePositionPerOrder ==
  positionBooked \subseteq Orders

PositionBookedRequiresTransferAgentConfirmation ==
  \A o \in Orders :
    o \in positionBooked => confirmationRef[o] # NoConfirmation

ActiveRequiresReconciledHistory ==
  \A o \in Orders :
    status[o] = Active => Reconciled \in seenStatuses[o]

CashCreditedRequiresRedemptionConfirmationHistory ==
  \A o \in Orders :
    status[o] = CashCredited => RedemptionConfirmed \in seenStatuses[o]

CurrentStatusInHistory ==
  \A o \in Orders :
    CreatedOrder(o) => status[o] \in seenStatuses[o]

NoFiddYieldSource ==
  \A o \in Orders :
    CreatedOrder(o) => productAsset[o] # FIDD

LedgerBalancedPerAsset ==
  ledgerDebit = ledgerCredit

LedgerAppendOnly ==
  ledgerEntries \subseteq ledgerEntries'

LedgerAppendOnlyTemporal ==
  [][LedgerAppendOnly]_vars

InboxDeduplicatesWorkerEffects ==
  workerEffects \subseteq inboxSeen

OutboxRetryDoesNotDuplicateBusinessEffects ==
  businessEffects \subseteq outboxEvents

WriteCommandCarriesCorrelationAndIdempotency ==
  \A o \in Orders :
    CreatedOrder(o)
      => /\ idempotencyKey[o] \in IdempotencyKeys
         /\ correlationId[o] \in CorrelationIds

LifecycleSafe ==
  /\ PositionBookedRequiresTransferAgentConfirmation
  /\ ActiveRequiresReconciledHistory
  /\ CashCreditedRequiresRedemptionConfirmationHistory
  /\ CurrentStatusInHistory
  /\ NoFiddYieldSource

UniquenessSafe ==
  /\ NoDuplicateIdempotency
  /\ NoDuplicateConfirmation
  /\ OnePositionPerOrder

LedgerSafe ==
  /\ LedgerBalancedPerAsset

MessagingSafe ==
  /\ InboxDeduplicatesWorkerEffects
  /\ OutboxRetryDoesNotDuplicateBusinessEffects

MetadataSafe ==
  WriteCommandCarriesCorrelationAndIdempotency

Inv ==
  /\ TypeOK
  /\ LifecycleSafe
  /\ UniquenessSafe
  /\ LedgerSafe
  /\ MessagingSafe
  /\ MetadataSafe

Safety ==
  /\ LifecycleSafe
  /\ UniquenessSafe
  /\ LedgerSafe
  /\ MessagingSafe
  /\ MetadataSafe

Init ==
  /\ status = [o \in Orders |-> NoStatus]
  /\ account \in [Orders -> Accounts]
  /\ idempotencyKey \in [Orders -> IdempotencyKeys]
  /\ correlationId \in [Orders -> CorrelationIds]
  /\ productAsset \in [Orders -> Assets]
  /\ confirmationRef = [o \in Orders |-> NoConfirmation]
  /\ redemptionRef = [o \in Orders |-> NoConfirmation]
  /\ positionBooked = {}
  /\ seenStatuses = [o \in Orders |-> {}]
  /\ ledgerDebit = [a \in Assets |-> 0]
  /\ ledgerCredit = [a \in Assets |-> 0]
  /\ ledgerEntries = {}
  /\ inboxSeen = {}
  /\ workerEffects = {}
  /\ outboxEvents = {}
  /\ businessEffects = {}

AddSeen(o, s) ==
  [seenStatuses EXCEPT ![o] = @ \cup {s}]

UnchangedOrderMetadata ==
  UNCHANGED <<account, idempotencyKey, correlationId, productAsset>>

UnchangedConfirmations ==
  UNCHANGED <<confirmationRef, redemptionRef>>

UnchangedLedger ==
  UNCHANGED <<ledgerDebit, ledgerCredit, ledgerEntries>>

UnchangedMessaging ==
  UNCHANGED <<inboxSeen, workerEffects, outboxEvents, businessEffects>>

UnchangedInboxEffects ==
  UNCHANGED <<inboxSeen, workerEffects, businessEffects>>

UnchangedPositions ==
  UNCHANGED positionBooked

CreateOrder(o, a, k, c, p, e) ==
  /\ o \in Orders
  /\ a \in Accounts
  /\ k \in IdempotencyKeys
  /\ c \in CorrelationIds
  /\ NonFiddAsset(p)
  /\ e \in EventIds
  /\ status[o] = NoStatus
  /\ \A other \in Orders :
       CreatedOrder(other)
         => ~(account[other] = a /\ idempotencyKey[other] = k)
  /\ status' = [status EXCEPT ![o] = Created]
  /\ account' = [account EXCEPT ![o] = a]
  /\ idempotencyKey' = [idempotencyKey EXCEPT ![o] = k]
  /\ correlationId' = [correlationId EXCEPT ![o] = c]
  /\ productAsset' = [productAsset EXCEPT ![o] = p]
  /\ seenStatuses' = AddSeen(o, Created)
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UNCHANGED
       << confirmationRef,
          redemptionRef,
          positionBooked,
          ledgerDebit,
          ledgerCredit,
          ledgerEntries,
          inboxSeen,
          workerEffects,
          businessEffects >>

Move(o, from, to, e) ==
  /\ o \in Orders
  /\ e \in EventIds
  /\ status[o] = from
  /\ CreatedOrder(o)
  /\ status' = [status EXCEPT ![o] = to]
  /\ seenStatuses' = AddSeen(o, to)
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UnchangedConfirmations
  /\ UnchangedLedger
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

CheckEligibility(o, e) == Move(o, Created, EligibilityChecked, e)
CheckDisclosures(o, e) == Move(o, EligibilityChecked, DisclosureChecked, e)
Approve(o, e) == Move(o, DisclosureChecked, Approved, e)
SubmitSubscription(o, e) == Move(o, CashLocked, SubscriptionSubmitted, e)
ObserveChainMirror(o, e) == Move(o, TransferAgentConfirmed, ChainMirrorObserved, e)
Reconcile(o, e) == Move(o, PositionBooked, Reconciled, e)
Activate(o, e) == Move(o, Reconciled, Active, e)
RequestRedemption(o, e) == Move(o, Active, RedemptionRequested, e)
ReserveShares(o, e) == Move(o, RedemptionRequested, SharesReserved, e)
SubmitRedemption(o, e) == Move(o, SharesReserved, RedemptionSubmitted, e)
SettleRedemption(o, e) == Move(o, CashCredited, Settled, e)

Cancel(o, e) ==
  \/ Move(o, Created, Cancelled, e)
  \/ Move(o, EligibilityChecked, Cancelled, e)
  \/ Move(o, DisclosureChecked, Cancelled, e)
  \/ Move(o, Approved, Cancelled, e)

CloseException(o, e) == Move(o, ExceptionOpen, ExceptionClosed, e)

LockCash(o, e) ==
  /\ o \in Orders
  /\ e \in EventIds
  /\ status[o] = Approved
  /\ status' = [status EXCEPT ![o] = CashLocked]
  /\ seenStatuses' = AddSeen(o, CashLocked)
  /\ ledgerDebit' =
       [ledgerDebit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerCredit' =
       [ledgerCredit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerEntries' = ledgerEntries \cup {productAsset[o]}
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UnchangedConfirmations
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

ConfirmTransferAgent(o, conf, e) ==
  /\ o \in Orders
  /\ conf \in Confirmations
  /\ conf # NoConfirmation
  /\ e \in EventIds
  /\ status[o] = SubscriptionSubmitted
  /\ \A other \in Orders : confirmationRef[other] # conf
  /\ status' = [status EXCEPT ![o] = TransferAgentConfirmed]
  /\ confirmationRef' = [confirmationRef EXCEPT ![o] = conf]
  /\ seenStatuses' = AddSeen(o, TransferAgentConfirmed)
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UNCHANGED redemptionRef
  /\ UnchangedLedger
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

BookPosition(o, e) ==
  /\ o \in Orders
  /\ e \in EventIds
  /\ status[o] \in {TransferAgentConfirmed, ChainMirrorObserved}
  /\ confirmationRef[o] # NoConfirmation
  /\ o \notin positionBooked
  /\ status' = [status EXCEPT ![o] = PositionBooked]
  /\ positionBooked' = positionBooked \cup {o}
  /\ seenStatuses' = AddSeen(o, PositionBooked)
  /\ ledgerDebit' =
       [ledgerDebit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerCredit' =
       [ledgerCredit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerEntries' = ledgerEntries \cup {productAsset[o]}
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UnchangedConfirmations
  /\ UnchangedInboxEffects

ConfirmRedemption(o, conf, e) ==
  /\ o \in Orders
  /\ conf \in Confirmations
  /\ conf # NoConfirmation
  /\ e \in EventIds
  /\ status[o] = RedemptionSubmitted
  /\ status' = [status EXCEPT ![o] = RedemptionConfirmed]
  /\ redemptionRef' = [redemptionRef EXCEPT ![o] = conf]
  /\ seenStatuses' = AddSeen(o, RedemptionConfirmed)
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UNCHANGED confirmationRef
  /\ UnchangedLedger
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

CreditCash(o, e) ==
  /\ o \in Orders
  /\ e \in EventIds
  /\ status[o] = RedemptionConfirmed
  /\ redemptionRef[o] # NoConfirmation
  /\ status' = [status EXCEPT ![o] = CashCredited]
  /\ seenStatuses' = AddSeen(o, CashCredited)
  /\ ledgerDebit' =
       [ledgerDebit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerCredit' =
       [ledgerCredit EXCEPT ![productAsset[o]] = @ + 1]
  /\ ledgerEntries' = ledgerEntries \cup {productAsset[o]}
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UnchangedConfirmations
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

OpenException(o, e) ==
  /\ o \in Orders
  /\ e \in EventIds
  /\ CreatedOrder(o)
  /\ status[o] \notin TerminalStatuses
  /\ status[o] # ExceptionOpen
  /\ status' = [status EXCEPT ![o] = ExceptionOpen]
  /\ seenStatuses' = AddSeen(o, ExceptionOpen)
  /\ outboxEvents' = outboxEvents \cup {e}
  /\ UnchangedOrderMetadata
  /\ UnchangedConfirmations
  /\ UnchangedLedger
  /\ UnchangedInboxEffects
  /\ UnchangedPositions

LeaseOutbox(e) ==
  /\ e \in outboxEvents
  /\ UNCHANGED vars

PublishOutbox(e) ==
  /\ e \in outboxEvents
  /\ businessEffects' = businessEffects \cup {e}
  /\ UNCHANGED
       << status,
          account,
          idempotencyKey,
          correlationId,
          productAsset,
          confirmationRef,
          redemptionRef,
          positionBooked,
          seenStatuses,
          ledgerDebit,
          ledgerCredit,
          ledgerEntries,
          inboxSeen,
          workerEffects,
          outboxEvents >>

ReceiveMessage(c, m) ==
  /\ c \in Consumers
  /\ m \in MessageIds
  /\ inboxSeen' =
       inboxSeen \cup {[consumer |-> c, message |-> m]}
  /\ UNCHANGED
       << status,
          account,
          idempotencyKey,
          correlationId,
          productAsset,
          confirmationRef,
          redemptionRef,
          positionBooked,
          seenStatuses,
          ledgerDebit,
          ledgerCredit,
          ledgerEntries,
          workerEffects,
          outboxEvents,
          businessEffects >>

ProcessMessage(c, m) ==
  /\ c \in Consumers
  /\ m \in MessageIds
  /\ [consumer |-> c, message |-> m] \in inboxSeen
  /\ workerEffects' =
       workerEffects \cup {[consumer |-> c, message |-> m]}
  /\ UNCHANGED
       << status,
          account,
          idempotencyKey,
          correlationId,
          productAsset,
          confirmationRef,
          redemptionRef,
          positionBooked,
          seenStatuses,
          ledgerDebit,
          ledgerCredit,
          ledgerEntries,
          inboxSeen,
          outboxEvents,
          businessEffects >>

DeleteMessage(c, m) ==
  /\ c \in Consumers
  /\ m \in MessageIds
  /\ [consumer |-> c, message |-> m] \in inboxSeen
  /\ UNCHANGED vars

Next ==
  \/ \E o \in Orders,
        a \in Accounts,
        k \in IdempotencyKeys,
        c \in CorrelationIds,
        p \in Assets,
        e \in EventIds :
       CreateOrder(o, a, k, c, p, e)
  \/ \E o \in Orders, e \in EventIds : CheckEligibility(o, e)
  \/ \E o \in Orders, e \in EventIds : CheckDisclosures(o, e)
  \/ \E o \in Orders, e \in EventIds : Approve(o, e)
  \/ \E o \in Orders, e \in EventIds : LockCash(o, e)
  \/ \E o \in Orders, e \in EventIds : SubmitSubscription(o, e)
  \/ \E o \in Orders, conf \in Confirmations, e \in EventIds :
       ConfirmTransferAgent(o, conf, e)
  \/ \E o \in Orders, e \in EventIds : ObserveChainMirror(o, e)
  \/ \E o \in Orders, e \in EventIds : BookPosition(o, e)
  \/ \E o \in Orders, e \in EventIds : Reconcile(o, e)
  \/ \E o \in Orders, e \in EventIds : Activate(o, e)
  \/ \E o \in Orders, e \in EventIds : RequestRedemption(o, e)
  \/ \E o \in Orders, e \in EventIds : ReserveShares(o, e)
  \/ \E o \in Orders, e \in EventIds : SubmitRedemption(o, e)
  \/ \E o \in Orders, conf \in Confirmations, e \in EventIds :
       ConfirmRedemption(o, conf, e)
  \/ \E o \in Orders, e \in EventIds : CreditCash(o, e)
  \/ \E o \in Orders, e \in EventIds : SettleRedemption(o, e)
  \/ \E o \in Orders, e \in EventIds : OpenException(o, e)
  \/ \E o \in Orders, e \in EventIds : Cancel(o, e)
  \/ \E o \in Orders, e \in EventIds : CloseException(o, e)
  \/ \E e \in EventIds : LeaseOutbox(e)
  \/ \E e \in EventIds : PublishOutbox(e)
  \/ \E c \in Consumers, m \in MessageIds : ReceiveMessage(c, m)
  \/ \E c \in Consumers, m \in MessageIds : ProcessMessage(c, m)
  \/ \E c \in Consumers, m \in MessageIds : DeleteMessage(c, m)

Spec == Init /\ [][Next]_vars

StateConstraint ==
  /\ \A a \in Assets : ledgerDebit[a] <= Cardinality(Orders) * 3
  /\ \A a \in Assets : ledgerCredit[a] <= Cardinality(Orders) * 3

====
