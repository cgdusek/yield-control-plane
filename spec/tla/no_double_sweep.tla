---- MODULE no_double_sweep ----
EXTENDS YieldLifecycle, TLAPS

NoDoubleSweepSafety ==
  /\ NoDuplicateIdempotency
  /\ NoDuplicateConfirmation

THEOREM InvImpliesNoDoubleSweepSafety ==
  Inv => NoDoubleSweepSafety
PROOF
  BY DEF Inv, Safety, UniquenessSafe, NoDoubleSweepSafety
====
