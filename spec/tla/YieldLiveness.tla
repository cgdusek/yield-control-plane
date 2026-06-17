---- MODULE YieldLiveness ----
EXTENDS YieldLifecycle

CreateProgress ==
  \E o \in Orders,
     a \in Accounts,
     k \in IdempotencyKeys,
     c \in CorrelationIds,
     p \in Assets,
     e \in EventIds :
    CreateOrder(o, a, k, c, p, e)

LifecycleProgress ==
  \/ CreateProgress
  \/ \E o \in Orders, e \in EventIds : CheckEligibility(o, e)
  \/ \E o \in Orders, e \in EventIds : CheckDisclosures(o, e)
  \/ \E o \in Orders, e \in EventIds : Approve(o, e)
  \/ \E o \in Orders, e \in EventIds : LockCash(o, e)
  \/ \E o \in Orders, e \in EventIds : SubmitSubscription(o, e)
  \/ \E o \in Orders, conf \in Confirmations, e \in EventIds :
       ConfirmTransferAgent(o, conf, e)
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

LifecycleFairSpec ==
  Init /\ [][LifecycleProgress]_vars /\ WF_vars(LifecycleProgress)

ExceptionProgress ==
  \/ CreateProgress
  \/ \E o \in Orders, e \in EventIds : OpenException(o, e)
  \/ \E o \in Orders, e \in EventIds : CloseException(o, e)

ExceptionFairSpec ==
  Init /\ [][ExceptionProgress]_vars /\ WF_vars(ExceptionProgress)

MessagingProgress ==
  \/ CreateProgress
  \/ \E e \in EventIds : PublishOutbox(e)
  \/ \E c \in Consumers, m \in MessageIds : ReceiveMessage(c, m)
  \/ \E c \in Consumers, m \in MessageIds : ProcessMessage(c, m)

MessagingFairSpec ==
  Init /\ [][MessagingProgress]_vars /\ WF_vars(MessagingProgress)

CreatedEventuallyActiveOrTerminal ==
  \A o \in Orders :
    [](CreatedOrder(o) => <>(status[o] \in {Active, Settled}))

ActiveEventuallyRedeemedOrTerminal ==
  \A o \in Orders :
    [](status[o] = Active => <>(status[o] = Settled))

OpenExceptionEventuallyClosedIfResolved ==
  \A o \in Orders :
    [](status[o] = ExceptionOpen => <>(status[o] = ExceptionClosed))

ReconciliationBreakEventuallyOpensException ==
  \A o \in Orders :
    [](CreatedOrder(o) => <>(status[o] \in {ExceptionOpen, ExceptionClosed}))

OutboxEventEventuallyPublishedOrFailed ==
  \A e \in EventIds :
    [](e \in outboxEvents => <>(e \in businessEffects))

LeaseDoesNotStayStuck ==
  OutboxEventEventuallyPublishedOrFailed

InboxMessageEventuallyProcessedOrDeduplicated ==
  \A pair \in InboxPairs :
    [](pair \in inboxSeen => <>(pair \in workerEffects))

====
