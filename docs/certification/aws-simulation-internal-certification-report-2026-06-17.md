# AWS Simulation Internal Certification Report - 2026-06-17

Report type: internal engineering evidence certificate and execution report.
Issued at: 2026-06-17T20:44:49Z.
Repository commit under test: `268e56b2107dc5793f5216ed7c2981c390be5fec`.
Region: `us-west-2`.
Scope: dedicated non-production AWS sandbox simulation for the yield control plane.

This report is not a SOC, ISO, regulatory, legal, tax, accounting, investment, production-deployment, or transfer-agent certification. It records the internal engineering evidence generated for the AWS simulation workstream.

## Certification Decision

Decision: passed for the scoped AWS simulation campaign.

The campaign passed after causal remediation of the failed live attempts. Budget was not recorded as a failure cause; it was treated as an admission guardrail. The final successful run completed deploy, smoke, bounded k6 load, SQS drain checks, FIS worker interruption, post-FIS stability, post-run database invariant certification, scoped infrastructure destroy, root bootstrap teardown, and final local validation.

## Evidence Boundary

Tracked evidence:

- Specification and control rationale: [AWS simulation and internal certification](../aws-certification.md).
- Operating procedure: [AWS simulation runbook](../runbooks/aws-simulation.md).
- Failure and remediation log: [AWS certification tracking](../trackers/aws-certification-simulation-tracking.md).
- Formal admission diagnosis: [AWS certification formal diagnosis](../trackers/aws-certification-formal-diagnosis.md).
- Coverage map: `spec/certification/aws_certification_coverage_map.json`.
- Repo surface map: `spec/refinement/repo_surface_coverage_map.json`.

Ignored local evidence retained under `artifacts/aws-certification/`:

- `command-manifest.json`
- `k6-summary.json`
- `db-invariant-report.json`
- `queue-drain-*.json`
- `fis-experiment.json`
- `fis-targets-*.json`
- `ecs-services-stability-*.json`
- `aws-inventory.json`
- `cost-summary.json`

The ignored evidence directory is intentionally not committed because it can contain account-specific identifiers, temporary bootstrap material, and environment-specific resource names.

## Timeline

All timestamps are UTC unless a source artifact records an AWS-local offset.

| Time | Command or gate | Result | Evidence |
| --- | --- | --- | --- |
| 2026-06-17T17:47:55Z | `make validate-tla`; `make validate-source-proofs`; certification domain tests | Passed | TLAPS proved lifecycle and capacity obligations; Kani verified 23 source-proof harnesses. |
| 2026-06-17T17:54:03Z | `AWS_PROFILE=root ... make aws-cert-teardown-iam`; root bootstrap with `$750` budget; `make aws-cert-preflight` under temporary role | Passed | Old bootstrap material removed; new temporary scoped-role credentials passed non-root preflight. |
| 2026-06-17T18:14:30Z | GitHub Actions run `27709578309` | Passed | Static validation and Postgres/LocalStack smoke lanes passed for committed SHA `268e56b`. |
| 2026-06-17T18:29:26Z | `AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy` | Passed | ECR image tags for `268e56b` verified; database secret recreated with immediate deletion semantics; ECS services created. |
| 2026-06-17T19:47:42Z | FIS target remediation deploy and `scripts/aws-cert-check-fis-targets.sh` | Passed | ECS services propagated tags to tasks; checker found 5 tagged worker task targets. |
| 2026-06-17T20:20:47Z | `make aws-cert-run` | Passed | Smoke, bounded k6, queue drain, FIS, ECS replacement stability, and post-FIS drain all passed. |
| 2026-06-17T20:25:00Z | `make aws-cert-collect` | Passed | Evidence collected; DB certifier reported 10 passed checks, 0 failures, 0 warnings. |
| 2026-06-17T20:33:47Z | `make aws-cert-destroy` | Passed | Scoped-role OpenTofu destroy removed 81 resources. |
| 2026-06-17T20:34:52Z | `AWS_PROFILE=root ... make aws-cert-teardown-iam` | Passed | Root-boundary bootstrap teardown completed after workload destroy. |
| 2026-06-17T20:44:49Z | `make generate-repo-surface-coverage-map`; `make validate`; `git diff --check` | Passed | Final local validation and whitespace checks passed after AWS run, collection, destroy, root teardown, and report creation. |

## Final Workload Results

AWS preflight:

- Caller identity: non-root assumed role.
- Region: `us-west-2`.
- Opt-in: `AWS_CERTIFICATION_ENABLED=1`.
- Budget guardrail: `yield-control-plane-cert-750-usd`.
- Budget limit: `$750`.
- Budget actual spend at run preflight: `$661.569`.
- Budget forecast at run preflight: `$1180.626`.
- FIS service-linked role: verified before workload execution.
- Teardown TTL: 24 hours.

k6 load result:

- Iterations: 1,021.
- Check passes: 3,522.
- Check failures: 0.
- Interrupted iterations: 0.
- HTTP failure rate: 0.00%.
- HTTP request duration p95: 109.57 ms.
- Workload profile: bounded constant-arrival-rate campaign with duplicate idempotency replays, conflict paths, FIDD yield rejection, redemption paths, and reconciliation mismatch injections.

Queue drain gates:

- Pre-run: passed with 0 source or DLQ messages.
- Post-smoke: passed with 0 source or DLQ messages.
- Post-k6: passed with 0 source or DLQ messages.
- Post-FIS: passed with 0 source or DLQ messages.
- Final collection drain: retained post-FIS passed state with 0 total messages.

FIS result:

- Experiment ID: `EXPMAH3JUMrvytyjVL`.
- Target: `aws:ecs:task` resources tagged `CertificationWorkstream=aws-simulation`.
- Target resolution: 5 tagged worker tasks found before run and before FIS.
- Action: `aws:ecs:stop-task`.
- Action state: completed.
- Experiment state: completed.
- Post-FIS ECS service stability: passed.

Database invariant certification:

- `no_duplicate_idempotency_records`: pass, observed 0 violations.
- `no_conflicting_idempotency_bodies`: pass, observed 0 violations.
- `no_duplicate_transfer_agent_confirmations`: pass, observed 0 violations.
- `one_position_per_order`: pass, observed 0 violations.
- `active_requires_reconciled_history`: pass, observed 0 violations.
- `ledger_balanced_per_asset_order_kind`: pass, observed 0 violations.
- `inbox_deduplicates_worker_effects`: pass, observed 0 violations.
- `outbox_retry_does_not_duplicate_business_events`: pass, observed 0 violations.
- `outbox_has_no_stale_unpublished_events`: pass, observed 0 violations.
- `ledger_append_only_trigger_enforced`: pass, observed 0 violations.

## Causal Failure Findings And Remedies

The following findings were causal to failed live attempts and were remedied before the passing campaign:

| Failure | Cause | Remedy | Verification |
| --- | --- | --- | --- |
| k6 completed but the campaign failed on async completion | The initial workload overshot the intended bounded campaign, counted expected 409/422 negative paths as HTTP failures, and left SQS backlog. | Added expected-status classification, per-run idempotency namespace, constant-arrival-rate sizing, and explicit SQS source/DLQ drain gates. | `make aws-cert-run` passed k6 and all drain gates. |
| Pre-run drain failed | The drain script requested unsupported SQS attribute `ApproximateAgeOfOldestMessage`. | Removed the unsupported attribute and retained queue depth checks that SQS supports directly. | `make validate-aws-certification` and subsequent drain gates passed. |
| Dirty-stack rerun was not meaningful | The previous high-volume failure left about 15k messages and worker scaling exposed RDS pool pressure. | Treated the run as failed evidence, collected what could be collected, destroyed the dirty stack, and redeployed clean infrastructure. | Clean redeploy and final workload passed. |
| CI failed after an earlier push | Static CI did not install `ripgrep`, but the AWS validator uses `rg`. | Installed `ripgrep` in the static GitHub Actions job. | Replacement run `27709578309` passed. |
| Clean redeploy failed on the database secret | The stable Secrets Manager name was still scheduled for deletion from a previous stack. | Set `recovery_window_in_days = 0`, enforced it in static validation, restored and force-deleted the stale secret. | Redeploy passed. |
| FIS failed after k6 and drain passed | First FIS use attempted to create `AWSServiceRoleForFIS` during `StartExperiment`, outside the scoped runner's authority. | Root bootstrap now creates or verifies the FIS service-linked role; scoped preflight verifies it before k6. | Preflight and final FIS experiment passed. |
| Happy-path smoke failed on a dirty but drained stack | Smoke used account/global assertions contaminated by historical data from prior failed attempts. | Smoke now uses a run-scoped policy key and filters assertions to the current order. | Happy-path smoke passed in the final run. |
| FIS target resolution returned an empty set | ECS services were tagged, but live ECS tasks had empty tag sets; FIS targets tasks by tags. | ECS services now propagate service tags to tasks, enable ECS managed tags, force fresh deployments after apply, and check FIS target resolvability before load and before FIS. | Pre-run and pre-FIS target checks found 5 tagged worker tasks; FIS completed. |

Budget was not a failure finding. The budget cap was increased to `$750` only to admit another bounded run after the account-month budget actual already exceeded the default `$50` guardrail.

## Standards Mapping

| Standard or guidance area | Evidence in this campaign |
| --- | --- |
| AWS Well-Architected operational excellence | Scripted preflight, deploy, run, collect, destroy, and runbook-driven remediation. |
| AWS Well-Architected reliability | ECS service stability checks, SQS drain gates, DLQs, retry-safe outbox/inbox, and FIS worker interruption. |
| AWS Well-Architected security | Root avoided outside bootstrap and teardown, scoped temporary role for deploy/run/collect/destroy, ECS task roles, KMS encryption, Secrets Manager, and no static runtime AWS keys. |
| AWS Well-Architected cost optimization | Budget guardrail, Fargate Spot workers, TTL tags, and mandatory teardown. |
| AWS Financial Services Industry Lens | Evidence pack for invariant-backed workflow safety, operational traceability, fault-injection evidence, and least-privilege execution. |
| AWS IAM root-user and least-privilege guidance | Root used only for bootstrap and teardown; runner role rejected root identity during workload commands. |
| ECS Fargate and Fargate Spot guidance | Workers used Spot plus On-Demand fallback; API retained an On-Demand floor. |
| AWS FIS guidance | Planned worker stop-task experiment with prechecked targets and post-experiment stability/drain evidence. |
| SQS visibility timeout and DLQ guidance | Queue depth and DLQ gates enforced before, during, and after workload phases. |
| NIST CSF 2.0 | Govern, identify, protect, detect, respond, and recover functions mapped through policy, evidence, monitoring, fault injection, and teardown. |
| NIST SP 800-53 Rev. 5 selected families | AC, AU, CM, CP, IA, RA, SC, SI evidence mapped through IAM, logs, configuration gates, recovery runbooks, identity checks, encryption, and invariant validation. |

## Residual Scope Limits

- This was a non-production sandbox simulation.
- No production transfer agent, production account, customer data, real credentials, or production financial system was used.
- This campaign does not prove every line of Rust with a theorem prover.
- This campaign does not establish legal, regulatory, SOC, ISO, investment, tax, accounting, transfer-agent, or production deployment certification.
- Liveness evidence is bounded and assumption-backed; it depends on the modeled fairness assumptions, ECS replacement, queue delivery, and external confirmation simulators.

## Closure

The AWS simulation campaign passed the internal engineering certification criteria for the scoped demo artifact. The evidence supports the claim that the repository now demonstrates a formally specified, invariant-backed, runtime-enforced financial workflow with AWS fault-injection and post-run invariant certification under the stated non-production assumptions.
