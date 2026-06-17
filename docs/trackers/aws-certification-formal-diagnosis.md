# AWS Certification Formal Diagnosis

Status: in-progress
Last Updated: 2026-06-17T17:47:55Z

## Objective

Prove and enforce the AWS certification campaign controls that address the previous failed run before rebuilding the cloud stack: the workload must not overproduce relative to the intended attempt target, expected negative responses must not be counted as request failures, queues must drain after each async phase, invalid SQS attribute usage must stay blocked, and service/certifier evidence must be collected before success is claimed.

## Boundary

This is an internal engineering verification layer. It does not prove AWS service internals, Cost Explorer freshness, RDS throughput, network delivery, legal compliance, regulatory certification, or production deployment safety. It proves a small admission protocol for clean queues and bounded load, then binds that protocol to executable scripts, Rust source proofs, TLC checks, and AWS run behavior.

## Diagnosis

| Finding | Formal Signal | Process Remedy |
| --- | --- | --- |
| Constant VUs created more work than the stated certification target. | `RateWithinQueueCapacity` and `RateWithinDbCapacity` are explicit admission predicates; Kani proves admitted rates are within both capacities. | k6 default changed to constant-arrival-rate from `CERT_TARGET_ATTEMPTS` and `CERT_DURATION`; stress runs require explicit rate override. |
| The default bounded load was still looser than necessary after the first fix. | The abstract rate is per tick, so the implementation can choose a safer tick without changing the proof. | The k6 default now uses a per-minute constant-arrival-rate profile; the admission script caps target attempts, scheduled iterations, and arrival rate before k6 starts. |
| Expected negative responses caused false HTTP failure evidence. | This is an implementation classification issue, not a TLAPS safety theorem. | k6 declares 2xx, 409, and 422 as expected statuses; unexpected 5xx responses still fail `http_req_failed`. |
| Dirty queues make a rerun uninterpretable. | `DirtyQueueBlocksAdmission` proves nonzero queue state blocks `Admissible`; Kani proves dirty queues cannot admit a campaign. | Queue-drain gates run before workload start and after each async phase. A dirty stack is collected and destroyed, not purged into a success claim. |
| Invalid SQS queue attributes broke the drain gate. | This is an AWS API contract issue, not a theorem-prover obligation. | Drain and collection use only visible, in-flight, and delayed SQS attributes; the static validator rejects `ApproximateAgeOfOldestMessage`. |
| FIS completion alone does not prove ECS replacement stabilized. | This is a runtime liveness evidence gap. | The run script now waits for all ECS services to be stable after FIS before post-FIS queue drain. |
| DB invariant evidence could be skipped during collection. | This is an evidence-chain gap. | Collection now runs the certifier as a one-off ECS task when cloud outputs exist and fails if it cannot produce `db-invariant-report.json` with zero failed checks. |
| TLC initially allowed idle stuttering forever. | TLC produced a counterexample for `EventuallySubmitted` from the idle initial state. | `Spec` now includes `WF_vars(StartCampaign)`, matching the runbook assumption that an enabled admitted campaign is actually started. |
| A proof harness over-specified rejection precedence. | Kani rejected the claim that dirty queue always returns the exact `DirtyQueue` error even when budget also fails first. | The source proof now separates "dirty queue blocks admission" from "dirty queue is reported when budget otherwise allows start." |
| TLC should not load TLAPS proof scaffolding as the executable model. | TLC failed when `YieldCertificationCapacity.tla` imported `TLAPS`. | The executable spec and proof wrapper are split: TLC checks `YieldCertificationCapacity.tla`; TLAPS checks `YieldCertificationCapacityProofs.tla`. |

Budget was not a prior-run failure cause. It is a next-run admission guard only: after the dirty stack was destroyed, preflight correctly blocked another deploy because the existing account-month AWS Budget actual spend already exceeded the original `$50` default.

## Budget Estimate

Scoped-role inspection on 2026-06-17 returned:

| Source | Value |
| --- | --- |
| Existing budget | `yield-control-plane-cert-50-usd` |
| Existing budget limit | `$50.00` |
| Existing budget actual month-to-date spend | `$650.121` |
| Existing budget forecast | `$1179.916` |
| Current-day Cost Explorer total for 2026-06-17 | `$2.6844876442` |

The next-run cap is therefore estimated at `$750`. That is not a retrospective finding; it is an explicit rerun guardrail chosen to exceed current actual spend by about `$99.879` while remaining bounded. The run remains fail-closed if actual spend exceeds the configured cap before deploy or run.

## S0-S6 Ladder

| Level | Artifact | Evidence |
| --- | --- | --- |
| S0 objective | Admit a cloud certification campaign only when queue cleanliness and capacity assumptions hold, and require separate budget admission before cloud spend. | This document and `docs/runbooks/aws-simulation.md`. |
| S1 formal spec | [YieldCertificationCapacity.tla](../../spec/tla/YieldCertificationCapacity.tla) | `Admissible`, `StartCampaign`, `SubmitLoad`, `DrainQueue`, `FinishCampaign`, and fairness assumptions. |
| S2 executable reference model | [certification.rs](../../crates/domain/src/certification.rs) | `admit_certification_campaign`, `arrival_rate_per_second`, `drain_after_one_tick`. |
| S3 implementation mapping | Certification scripts and k6 workload. | `aws-cert-preflight.sh`, `aws-cert-wait-queues-drained.sh`, `aws-cert-run.sh`, `aws_certification_load.js`. |
| S4 proof obligations | TLAPS theorems and Kani harnesses. | Budget, dirty queue, queue capacity, DB capacity, admission safety, rate ceiling, and bounded drain obligations. |
| S5 machine checks | Local gates. | `make validate-tla`, `make validate-source-proofs`, `cargo test -p institutional-yield-domain certification --all-features`. |
| S6 assumptions | External service and measurement assumptions. | AWS budget spend must be fresh enough for preflight, measured capacity must be conservative, and root is limited to bootstrap or teardown. |

## Proof Obligations

| Obligation | Machine Check | Result |
| --- | --- | --- |
| `Admissible => BudgetWithinLimit` | TLAPS `AdmissibleImpliesBudgetWithinLimit` | verified |
| `~BudgetWithinLimit => ~Admissible` | TLAPS `BudgetNotWithinLimitBlocksAdmission` | verified |
| `queue # 0 => ~Admissible` | TLAPS `DirtyQueueBlocksAdmission` | verified |
| `~RateWithinQueueCapacity => ~Admissible` | TLAPS `QueueRateNotWithinCapacityBlocksAdmission` | verified |
| `~RateWithinDbCapacity => ~Admissible` | TLAPS `DbRateNotWithinCapacityBlocksAdmission` | verified |
| `StartCampaign` preserves admission safety | TLAPS `StartCampaignImpliesAdmissionSafety` | verified |
| Accepted finite campaign completes under fairness | TLC `AcceptedCampaignEventuallyCompletes` | bounded-pass |
| Over-budget starts are rejected in enforced mode for rerun admission | Kani `over_budget_blocks_enforced_campaign` | verified |
| Cleanup mode can collect evidence over budget after failure | Kani `cleanup_mode_allows_over_budget_evidence_collection` | verified |
| Dirty queues block campaign start | Kani `dirty_queue_blocks_campaign_start` | verified |
| Dirty queue error is exact when budget allows | Kani `dirty_queue_is_reported_when_budget_allows_start` | verified |
| Zero duration blocks campaign start | Kani `zero_duration_blocks_campaign_start` | verified |
| Admitted rate stays within queue and DB capacity | Kani `admitted_campaign_rate_is_within_queue_and_db_capacity` | verified |
| Arrival rate is a positive ceiling | Kani `arrival_rate_is_positive_ceiling_for_bounded_inputs` | verified |
| Drain ticks never increase queue length | Kani `drain_tick_never_increases_queue` | verified |
| Positive capacity drains bounded queue | Kani `positive_capacity_eventually_drains_bounded_queue` | verified |

## Best Process Remedy

Before any rebuild or rerun:

1. Run `make validate-tla` and require TLAPS/TLC success for the capacity model.
2. Run `make validate-source-proofs` and require the Kani source-proof gate to pass.
3. Run `cargo test -p institutional-yield-domain certification --all-features`.
4. Run `make validate-aws-certification` so the script layer still references the proof artifacts, Rust model, queue gate, ECS stability gate, certifier task, budget mode, and k6 rate model.
5. Run `make aws-cert-preflight` from the scoped role and require non-root identity, `us-west-2`, teardown TTL, matching budget limit, and actual spend within the configured cap.

The default budget remains `$50`. Because the existing monthly AWS Budget reports actual spend around `$650`, another run requires an explicit budget override rather than silently weakening the default:

```bash
export AWS_CERT_BUDGET_LIMIT_USD=750
export AWS_CERT_BUDGET_NAME=yield-control-plane-cert-750-usd
```

That override is a campaign parameter for the next run, not a prior-run finding. It must be created or verified by root bootstrap, inherited into the temporary role env file, recorded by preflight, passed to OpenTofu, and kept fail-closed if actual spend exceeds the override.

## Validation Record

```bash
make validate-tla
make validate-source-proofs
cargo test -p institutional-yield-domain certification --all-features
```

`make validate-tla` passed after the spec/proof split and `WF_vars(StartCampaign)` remedy. `make validate-source-proofs` passed with 23 Kani harnesses and 0 failures. The domain certification unit tests passed. `cargo fmt --all --check`, workspace clippy, `cargo test -p institutional-yield-certifier --all-features`, `make validate-aws-certification`, `make validate-docs`, `make validate-repo-surface-coverage-map`, and `git diff --check` also passed before budget rebootstrap.
