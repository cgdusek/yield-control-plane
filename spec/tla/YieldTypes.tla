---- MODULE YieldTypes ----
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
  Orders,
  Accounts,
  IdempotencyKeys,
  Confirmations,
  MessageIds,
  EventIds,
  Consumers,
  CorrelationIds,
  Assets,
  FIDD

NoStatus == "NoStatus"
Created == "Created"
EligibilityChecked == "EligibilityChecked"
DisclosureChecked == "DisclosureChecked"
Approved == "Approved"
CashLocked == "CashLocked"
SubscriptionSubmitted == "SubscriptionSubmitted"
TransferAgentConfirmed == "TransferAgentConfirmed"
ChainMirrorObserved == "ChainMirrorObserved"
PositionBooked == "PositionBooked"
Reconciled == "Reconciled"
Active == "Active"
RedemptionRequested == "RedemptionRequested"
SharesReserved == "SharesReserved"
RedemptionSubmitted == "RedemptionSubmitted"
RedemptionConfirmed == "RedemptionConfirmed"
CashCredited == "CashCredited"
Settled == "Settled"
ExceptionOpen == "ExceptionOpen"
ExceptionClosed == "ExceptionClosed"
Cancelled == "Cancelled"

StatusSet ==
  { NoStatus,
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
    Cancelled }

TerminalStatuses == {Settled, ExceptionClosed, Cancelled}

NoConfirmation == "NoConfirmation"
ConfirmationRefs == Confirmations \cup {NoConfirmation}

InboxPairs == [consumer: Consumers, message: MessageIds]

NonFiddAsset(a) == a \in Assets /\ a # FIDD

====
