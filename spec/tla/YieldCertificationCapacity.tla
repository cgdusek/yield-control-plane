---- MODULE YieldCertificationCapacity ----
EXTENDS Naturals

CONSTANTS
  BudgetLimit,
  ActualSpend,
  ArrivalRate,
  QueueDrainRate,
  DbCapacity,
  TargetTicks,
  InitialQueue

VARIABLES
  phase,
  queue,
  remaining,
  startQueue

vars == <<phase, queue, remaining, startQueue>>

Phases == {"Idle", "Running", "Done"}

BudgetWithinLimit == ActualSpend <= BudgetLimit
CleanQueueStart == queue = 0
RateWithinQueueCapacity == ArrivalRate <= QueueDrainRate
RateWithinDbCapacity == ArrivalRate <= DbCapacity

Admissible ==
  /\ BudgetWithinLimit
  /\ CleanQueueStart
  /\ RateWithinQueueCapacity
  /\ RateWithinDbCapacity

TypeOK ==
  /\ phase \in Phases
  /\ queue \in Nat
  /\ remaining \in Nat
  /\ startQueue \in Nat

AdmissionSafety ==
  /\ TypeOK
  /\ phase = "Running" =>
       /\ startQueue = 0
       /\ BudgetWithinLimit
       /\ RateWithinQueueCapacity
       /\ RateWithinDbCapacity

QueueNeverNegative == queue \in Nat

Init ==
  /\ phase = "Idle"
  /\ queue = InitialQueue
  /\ remaining = TargetTicks
  /\ startQueue = InitialQueue

StartCampaign ==
  /\ phase = "Idle"
  /\ Admissible
  /\ phase' = "Running"
  /\ startQueue' = queue
  /\ UNCHANGED <<queue, remaining>>

SubmitLoad ==
  /\ phase = "Running"
  /\ remaining > 0
  /\ queue' = queue + ArrivalRate
  /\ remaining' = remaining - 1
  /\ UNCHANGED <<phase, startQueue>>

DrainQueue ==
  /\ phase = "Running"
  /\ queue > 0
  /\ queue' = IF queue <= QueueDrainRate THEN 0 ELSE queue - QueueDrainRate
  /\ UNCHANGED <<phase, remaining, startQueue>>

FinishCampaign ==
  /\ phase = "Running"
  /\ remaining = 0
  /\ queue = 0
  /\ phase' = "Done"
  /\ UNCHANGED <<queue, remaining, startQueue>>

Next == StartCampaign \/ SubmitLoad \/ DrainQueue \/ FinishCampaign

Spec ==
  /\ Init
  /\ [][Next]_vars
  /\ WF_vars(StartCampaign)
  /\ WF_vars(SubmitLoad)
  /\ WF_vars(DrainQueue)
  /\ WF_vars(FinishCampaign)

EventuallySubmitted == <> (remaining = 0)
FiniteLoadEventuallyDrains == [](remaining = 0 => <> (queue = 0))
AcceptedCampaignEventuallyCompletes == [](phase = "Running" => <> (phase = "Done"))

====
