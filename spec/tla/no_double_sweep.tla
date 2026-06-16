---- MODULE no_double_sweep ----
EXTENDS Naturals, Sequences

CONSTANTS Orders, Accounts, IdempotencyKeys, Confirmations

VARIABLES created, booked, confirmations

Init ==
  /\ created = {}
  /\ booked = {}
  /\ confirmations = {}

Create(order, account, key) ==
  /\ order \in Orders
  /\ account \in Accounts
  /\ key \in IdempotencyKeys
  /\ \A o \in created : ~(o.account = account /\ o.key = key)
  /\ created' = created \cup {[order |-> order, account |-> account, key |-> key]}
  /\ UNCHANGED <<booked, confirmations>>

Book(order, confirmation) ==
  /\ order \in Orders
  /\ confirmation \in Confirmations
  /\ \E o \in created : o.order = order
  /\ confirmation \notin confirmations
  /\ confirmations' = confirmations \cup {confirmation}
  /\ booked' = booked \cup {[order |-> order, confirmation |-> confirmation]}
  /\ UNCHANGED created

Next ==
  \/ \E order \in Orders, account \in Accounts, key \in IdempotencyKeys : Create(order, account, key)
  \/ \E order \in Orders, confirmation \in Confirmations : Book(order, confirmation)

NoDuplicateIdempotency ==
  \A a \in Accounts, k \in IdempotencyKeys :
    Cardinality({o \in created : o.account = a /\ o.key = k}) <= 1

NoDuplicateConfirmation ==
  \A c \in Confirmations :
    Cardinality({b \in booked : b.confirmation = c}) <= 1

Spec == Init /\ [][Next]_<<created, booked, confirmations>>

THEOREM Spec => []NoDuplicateIdempotency
THEOREM Spec => []NoDuplicateConfirmation
====
