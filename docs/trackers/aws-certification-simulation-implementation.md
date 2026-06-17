# AWS Certification Simulation Implementation

Status: in-progress

## Work Breakdown

| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| C1 | Cert-mode config and messaging behavior | `crates/config`, `crates/messaging`, `services/worker` | complete |
| C2 | Database invariant certifier | `services/certifier` | complete |
| C3 | AWS simulation infrastructure | `infra/aws-simulation` | complete |
| C4 | Workload and lifecycle scripts | `spec/certification`, `scripts/aws-cert-*.sh` | in-progress |
| C5 | Documentation and gate wiring | `docs`, `Makefile`, `scripts/validate-all.sh` | complete |
| C6 | Validation and closure | `AGENT_TRACKER.md` | complete |
| C7 | Live AWS campaign and teardown | `scripts/aws-cert-*.sh`, `infra/aws-simulation`, `artifacts/aws-certification/` | in-progress |
| C8 | Hygiene hardening and final audit closure | `.dockerignore`, `scripts/validate-aws-certification.sh`, docs, tracker, generated coverage map | in-progress |

## Edit Plan

The implementation keeps existing LocalStack behavior unchanged in local/dev mode. Cert mode requires explicit opt-in and uses AWS SDK default endpoint and credential resolution. Worker SNS/SQS configuration accepts real AWS ARNs and queue URLs only in cert mode.

## Generated Artifact Plan

Evidence produced by AWS campaigns is ignored under `artifacts/aws-certification/`. The checked-in JSON map is source-controlled because it defines required surfaces and evidence outputs.

## Gate Integration Plan

`make validate-aws-certification` is non-cloud and is included in `make validate`. Opt-in AWS commands are separate Makefile targets and are not run by CI.

## Risk Register

| Risk | Mitigation |
| --- | --- |
| Accidental real AWS usage from local mode | Local/dev endpoint validation remains fail-closed. |
| Root credentials used for iteration | Preflight rejects root caller identity. |
| Budget overrun | `$50` budget validation and TTL tags are required before deployment. |
| Budget object exists but is already exceeded | Preflight now reports actual/forecast spend and rejects deploy/run when actual spend exceeds the `$50` limit; collect/destroy use cleanup mode so resources can still be torn down. |
| Budget increase is needed for an authorized rerun after prior monthly spend | Keep the `$50` default, but require an explicit `AWS_CERT_BUDGET_LIMIT_USD` and matching budget name for any bounded rerun above the default. |
| Destroy deletes a pre-existing guardrail budget | Destroy detaches the imported budget from OpenTofu state; root teardown deletes it only if bootstrap created it. |
| Fargate Spot interruption creates duplicate effects | FIS stop-task plus post-run certifier checks inbox/outbox/idempotency/ledger invariants. |
| Static artifact drift | `make validate-aws-certification` checks required files, defaults, scripts, and coverage map. |
| Temporary credentials entering Docker build context | `.dockerignore` excludes ignored evidence and credential artifacts; the certification validator and deploy script enforce this before Docker builds. |
| First-use AWS service-linked roles and Cloud Map Route 53 calls | Bootstrap runner role includes scoped service-linked role creation and private hosted-zone permissions needed by ECS, ELB, RDS, and service discovery. |
| Provider default tags require ECS service-linked role tagging | Bootstrap runner role allows tag reconciliation only on `AWSServiceRoleForECS*`, and the validator requires that scoped permission. |
| Failed service-linked role tagging leaves tainted state | After fixing scoped tag permission, untaint `aws_iam_service_linked_role.ecs` before retry so OpenTofu reconciles the existing AWS-managed role instead of replacing it while ECS services depend on it. |
| Fargate worker services reject placement strategies | Worker services rely on capacity providers and subnet placement; `make validate-aws-certification` rejects `ordered_placement_strategy` in the stack. |
| Encrypted SNS-to-SQS fanout silently drops before workers | KMS policy grants `sns.amazonaws.com` `kms:GenerateDataKey*` and `kms:Decrypt` for the domain topic, and subscriptions enable raw message delivery so workers receive `EventEnvelope` JSON instead of an SNS wrapper. |
| k6 marks expected negative tests as failed HTTP requests | The load script declares expected statuses for 2xx, 409, and 422 so intentional idempotency conflicts and FIDD-yield rejections remain checks, while unexpected 5xx responses still trip `http_req_failed`. |
| Constant VUs overproduce async backlog relative to the stated attempt target | The load model now uses a 30-minute constant-arrival-rate profile derived from `CERT_TARGET_ATTEMPTS`, with an explicit `CERT_RATE_PER_MINUTE` override for stress campaigns. |
| Passing k6 while queues lag would overclaim completion | `scripts/aws-cert-wait-queues-drained.sh` gates pre-run, post-smoke, post-k6, post-FIS, and collection evidence on zero source/DLQ visible, in-flight, and delayed messages. |
| SQS drain gate assumes CloudWatch-only metrics are queue attributes | Drain and collection use only valid `GetQueueAttributes` values for visible, in-flight, and delayed counts; oldest-message age belongs in CloudWatch metric evidence, not the drain gate. |
| Failure collection blocks teardown when drain is expected to fail | `aws-cert-collect` preserves failed drain evidence as `queue-drain-final.json` and continues collecting inventory/cost/DB evidence so failed campaigns can be torn down cleanly. |
| CloudWatch Logs cannot use simulation KMS key | KMS policy grants the regional CloudWatch Logs service encryption rights for `/ecs/<workload>/*` log groups. |
| FIS completion does not prove ECS services stabilized | `scripts/aws-cert-wait-ecs-services-stable.sh` waits for all ECS services before smoke and after FIS, and records service stability evidence. |
| DB invariant certifier could be skipped in cloud collection | `aws-cert-collect` now runs the certifier as a one-off ECS task when cloud outputs are present and fails if the report is missing or has failed checks. |

## Decisions

- Use ECS/Fargate instead of EKS to match the locked plan.
- Use public ECS subnets with security-group-limited ingress for a short-lived sandbox to avoid NAT gateway cost while keeping RDS private.
- Keep AWS execution out of CI; CI validates the AWS command surface and fail-closed gates only.
- Treat over-broad Docker build context as a failed hygiene gate. Even when final runtime images copy only binaries, bootstrap credentials must be rotated after any suspect context exposure.
- Bootstrap may be rerun for the same ephemeral bridge user during remediation. It deletes existing access keys for that user before issuing a replacement key, avoiding orphaned bridge-user credentials.
- Model the ECS service-linked role in OpenTofu and grant the temporary runner only the ECS service-linked role tag permissions needed by provider default tags.
- Grant ECS service-linked role delete/status permission for final teardown, but do not replace a tainted ECS service-linked role during remediation when active ECS services may already use it.
- Do not express worker spreading with ECS placement strategies under Fargate; the static validator enforces this AWS constraint.
- Treat `Created`-only cloud smoke plus `AWS/SNS NumberOfNotificationsFailed` as encrypted fanout failure until KMS policy and raw delivery are verified.
- Treat queue drain as a first-class certification gate. A run with passing request metrics but non-empty worker queues is incomplete, not certified.
- Use constant-arrival-rate for the default campaign so the workload matches the documented target attempts without accidentally turning a certification run into an unbounded soak test.
- Treat budget-limit changes as campaign parameters. The default remains `$50`; a higher rerun cap must be explicit, preflight-verified, and passed through OpenTofu.
- Treat budget overruns as rerun admission blockers, not root causes of the previous failed workload unless a failed command actually exceeded the configured budget gate.

## Deferred Items

Third-party audit attestation, production external transfer-agent certification, TLS/custom domain, and production account deployment are outside this internal evidence workstream. The live AWS campaign remains open until deployment, workload, collection, destroy, and root teardown have executable evidence.
