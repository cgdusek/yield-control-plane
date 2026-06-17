---- MODULE YieldCertificationCapacityProofs ----
EXTENDS YieldCertificationCapacity, TLAPS

THEOREM AdmissibleImpliesBudgetWithinLimit ==
  Admissible => BudgetWithinLimit
PROOF
  BY SMT DEF Admissible, BudgetWithinLimit

THEOREM BudgetNotWithinLimitBlocksAdmission ==
  ~BudgetWithinLimit => ~Admissible
PROOF
  BY SMT DEF Admissible, BudgetWithinLimit

THEOREM DirtyQueueBlocksAdmission ==
  queue # 0 => ~Admissible
PROOF
  BY SMT DEF Admissible, CleanQueueStart

THEOREM QueueRateNotWithinCapacityBlocksAdmission ==
  ~RateWithinQueueCapacity => ~Admissible
PROOF
  BY SMT DEF Admissible, RateWithinQueueCapacity

THEOREM DbRateNotWithinCapacityBlocksAdmission ==
  ~RateWithinDbCapacity => ~Admissible
PROOF
  BY SMT DEF Admissible, RateWithinDbCapacity

THEOREM StartCampaignImpliesAdmissionSafety ==
  TypeOK /\ StartCampaign => AdmissionSafety'
PROOF
  BY SMT DEF StartCampaign,
             AdmissionSafety,
             Admissible,
             TypeOK,
             BudgetWithinLimit,
             RateWithinQueueCapacity,
             RateWithinDbCapacity,
             CleanQueueStart,
             Phases

====
