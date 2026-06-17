# AWS Certification Simulation Tracking

Status: in-progress
Last Updated: 2026-06-17T18:03:59Z

## Current Phase

C7/C8 live AWS remediation: dirty stack destroyed; formal admission proof and Kani source-proof remedy completed before any rebuild; `$750` next-run budget guardrail created and scoped-role preflight passed; CI static job ripgrep fix in progress.

## Live Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| Runtime config split | complete | `crates/config`, `crates/messaging`, `services/worker` |
| Rust DB certifier | complete | `services/certifier` |
| AWS IaC | complete | `infra/aws-simulation` |
| k6 workload | in-progress | `spec/certification/aws_certification_load.js`; remediating expected-status and arrival-rate smells after first live run |
| Opt-in AWS command scripts | complete | `scripts/aws-cert-*.sh` |
| Docs and standards map | complete | `docs/aws-certification.md`, `spec/certification/aws_certification_coverage_map.json` |
| Local validation | complete | `make validate`; `make validate-aws-certification` with OpenTofu installed; DB-backed persistence tests; `make smoke`; `make smoke-failure-paths` |
| Root bootstrap to temporary role | complete | `make aws-cert-bootstrap-iam`; `make aws-cert-preflight` passed as assumed role |
| Docker build-context hygiene | complete | `.dockerignore`; `make validate-aws-certification` now enforces sensitive path exclusions |
| Live AWS deploy/run/collect/destroy | in-progress | Deploy passed after SLR/Fargate/KMS fixes; latest k6 run completed but failed due expected negative responses counting as HTTP failures and worker queue backlog |
| Formal admission diagnosis | complete | `docs/trackers/aws-certification-formal-diagnosis.md`; `make validate-tla`; `make validate-source-proofs`; certification domain tests |
| Budget guardrail ownership | complete | `make aws-cert-destroy` detaches imported budget state; root teardown deletes the budget only when bootstrap created it |
| Next-run budget estimate | complete | Existing monthly budget actual `$650.121`; current-day Cost Explorer `$2.6844876442`; next guardrail cap estimated at `$750` |
| Bootstrap IAM teardown and rotation | complete | Old bridge user/role were deleted, `$750` budget guardrail was created/verified, and fresh assumed-role credentials passed preflight |

## Phase Log

| Phase | Status | Notes |
| --- | --- | --- |
| C1 | complete | Cert mode requires opt-in and `us-west-2`; local/dev still require LocalStack. |
| C2 | complete | Certifier emits JSON and fails on invariant violations. |
| C3 | complete | OpenTofu stack declares ECS, RDS, SNS/SQS, DLQs, KMS, Secrets Manager, CloudWatch, budget, and FIS. |
| C4 | complete | k6 and scripts are explicit opt-in and write ignored evidence artifacts. |
| C5 | complete | Docs and validation wiring added. |
| C6 | complete | Full local validation, stricter OpenTofu formatting validation, and runtime baseline passed. |
| C7 | in-progress | Live AWS execution opened with sandbox root bootstrap and temporary role handoff. |
| C8 | in-progress | Build-context, service-linked role, Fargate service-configuration, encrypted fanout, k6 classification, and queue-drain smells found during live deploy/run; patching validators/docs and rerunning with scoped credentials. |

## Command Log

| Command | Result | Notes |
| --- | --- | --- |
| `git status --short --branch` | passed | Started from clean `main...origin/main`. |
| `make validate-aws-certification` | passed | Static AWS certification gate passed; OpenTofu was not installed, so the optional `tofu fmt` check was skipped. |
| `brew install opentofu k6` | passed | Installed local OpenTofu and k6 tooling for stricter certification script validation; no AWS calls were made. |
| `make validate-aws-certification` | failed | With OpenTofu installed, `tofu fmt -check` rejected `infra/aws-simulation/main.tf`. |
| `tofu fmt infra/aws-simulation && make validate-aws-certification` | passed | OpenTofu formatting was corrected and the static AWS certification gate passed without AWS calls. |
| `make validate` | failed | Repo surface coverage map was stale after tracker edits; regenerate the map and rerun validation. |
| `make generate-repo-surface-coverage-map && make validate` | passed | Full static gate passed after map regeneration, including TLAPS/TLC, Kani, coverage maps, AWS certification static validation with OpenTofu formatting, docs, Rust, and frontend. |
| `make dev-reset && make dev-up && RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features && make smoke && make smoke-failure-paths && make dev-down` | passed | Clean local runtime baseline passed with DB-backed tests and happy/failure smoke gates. |
| `AWS_PROFILE=root ... make aws-cert-bootstrap-iam` | failed then passed | Initial root-to-role flow failed because root cannot assume roles directly, then the direct user trust failed as an invalid principal. Bootstrap now creates an ephemeral bridge user and trusts the account principal while narrowing assume-role in the bridge user's identity policy. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-preflight` | passed | Preflight confirmed assumed-role identity, `us-west-2`, `$50` budget, teardown TTL, and non-root execution. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-deploy` | failed | Earlier attempts exposed missing Budgets tag permissions, unknown OpenTofu resource keys, unsupported FIS target syntax, and amd64 QEMU instability. These were remediated with IAM permissions, static keys, corrected FIS schema, and ARM64 image/runtime defaults. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-deploy` | canceled | Canceled before Docker push after discovering `.dockerignore` did not explicitly exclude `artifacts/`; treating this as a credential-hygiene failure and rotating temporary credentials before retry. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-destroy` | failed then remediated | ECR repositories were destroyed, but budget deletion failed because AWS Budgets maps deletion to `budgets:ModifyBudget`. Destroy now detaches the budget from OpenTofu state before workload teardown, and bootstrap policy includes `budgets:ModifyBudget` for provider operations. |
| `AWS_PROFILE=root ... make aws-cert-teardown-iam` | passed | Deleted the old bridge user and runner role. The `$50` budget remained because the bootstrap state recorded it as pre-existing guardrail material. |
| `AWS_PROFILE=root ... make aws-cert-bootstrap-iam`; `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-preflight` | passed | Minted fresh temporary role credentials and confirmed non-root assumed-role execution in `us-west-2`. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-deploy` | failed | Full apply reached VPC/SNS/SQS/ECR creation, then failed on first-use service-linked role permissions, Route 53 private hosted-zone permission for Cloud Map, IAM attached-policy inspection, and CloudWatch Logs KMS key policy. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-deploy` | failed | Retry created ALB, Cloud Map, log groups, and RDS, then failed reconciling partial IAM roles because `iam:ListInstanceProfilesForRole` was missing and ECS capacity providers still needed an explicit ECS service-linked role. |
| `AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy` | failed | Infra-only retry verified existing ECR image tags and created API/mock ECS services, then worker ECS services failed because Fargate does not support placement strategies and the modeled ECS service-linked role needed scoped tag permission for provider default tags. |
| `tofu fmt -recursive infra/aws-simulation`; `bash -n scripts/aws-cert-bootstrap-iam.sh scripts/validate-aws-certification.sh`; `make validate-aws-certification` | passed | Validated service-linked role tag permission, capacity-provider service dependencies, and Fargate placement-strategy rejection before retrying AWS. |
| `AWS_PROFILE=root ... AWS_CERT_BOOTSTRAP_SUFFIX=20260617154021 make aws-cert-bootstrap-iam`; `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-preflight` | passed | Updated active runner policy for the same campaign suffix, rotated bridge-user key, and confirmed assumed-role non-root preflight. |
| `AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy` | failed | OpenTofu attempted to replace tainted `aws_iam_service_linked_role.ecs`; delete was denied and replacement is inappropriate while existing ECS services may already depend on the AWS-managed role. |
| `tofu untaint aws_iam_service_linked_role.ecs`; root bootstrap policy update; `make validate-aws-certification` | passed | Added scoped ECS SLR delete/status permission for final teardown, then reconciled the existing role instead of replacing it during deploy retry. |
| `AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy` | passed | ECR tag verification passed; ECS capacity providers attached; ECS service-linked role updated in place; all API, mock, and worker services reached desired count. |
| `make aws-cert-run` | failed | Happy-path smoke created order `1f7dddf4-dd53-4107-bd29-59a492fc7c96`, but it remained `Created`; outbox published one SNS message, queues/DLQs were empty, and `AWS/SNS NumberOfNotificationsFailed` was `4`, matching four encrypted SQS subscriptions. |
| `tofu fmt -recursive infra/aws-simulation`; `bash -n scripts/aws-cert-collect.sh scripts/validate-aws-certification.sh`; `make validate-aws-certification`; `AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy` | passed | Applied encrypted fanout fix: KMS key policy allows `sns.amazonaws.com` delivery to encrypted SQS queues, subscriptions use raw message delivery, and collection queue iteration is fixed. |
| `make aws-cert-run` | failed | Smoke and failure-path checks passed, and k6 completed 30 minutes with 27,949 iterations, 99.97% check success, and p95 latency 218ms, but `http_req_failed=10.37%` failed because expected 409/422 negative tests counted as HTTP failures; source queues also had transfer-agent backlog, so async completion was not proven. |
| `bash -n scripts/aws-cert-run.sh scripts/aws-cert-collect.sh scripts/aws-cert-wait-queues-drained.sh scripts/validate-aws-certification.sh`; `make validate-aws-certification`; `k6 inspect spec/certification/aws_certification_load.js` | passed | Added expected-status classification, constant-arrival-rate load model, per-run idempotency namespace, FIS wait loop, and queue-drain gate with static validation and k6 option parsing. |
| `make aws-cert-run` | failed | Pre-run drain failed before workload start because `ApproximateAgeOfOldestMessage` is a CloudWatch metric, not a valid SQS `GetQueueAttributes` attribute. |
| `make aws-cert-run` retry with scaled workers | interrupted | Pre-run drain found about 15k messages from the failed high-volume campaign; scaling workers exposed RDS pool timeouts, so the retry was stopped and the dirty stack will be collected/destroyed rather than purged. |
| `bash -n scripts/aws-cert-collect.sh scripts/validate-aws-certification.sh`; `make validate-aws-certification`; `make validate-docs` | passed | Hardened collection so failed-drain evidence is retained and teardown can proceed after a failed campaign. |
| `AWS_CERT_QUEUE_DRAIN_TIMEOUT_SECONDS=0 make aws-cert-collect` | passed | Collected failed campaign evidence; `queue-drain-final.json` retained failed drain status with 16,411 source messages. |
| `make aws-cert-destroy` | passed | Dirty AWS stack destroyed: 81 resources removed through the scoped role. |
| cost/budget inspection | failed guardrail | Cost Explorer current-day estimate was about `$2.68`, but the configured `$50` AWS Budget reports actual monthly spend about `$650`; preflight now rejects deploy/run when budget actual spend exceeds the limit. |
| `make validate-tla`; `make validate-source-proofs`; certification domain tests | passed | Capacity model split from proof wrapper; TLAPS proved 12 capacity obligations; TLC passed the fair admitted-campaign model; Kani passed 23 source-proof harnesses including AWS certification admission. |
| `cargo fmt --all --check`; workspace clippy; certifier tests; AWS static validator; docs/map validators; `git diff --check` | passed | Post-remedy local gates passed before budget rebootstrap. |
| scoped-role cost and budget inspection | passed | `yield-control-plane-cert-50-usd` actual spend `$650.121`, forecast `$1179.916`; 2026-06-17 Cost Explorer services total `$2.6844876442`; budget is a next-run admission guard, not a prior-run failure cause. |
| `make validate` | passed | Full local/static gate passed after formal diagnosis, budget-boundary tracker edits, and repo surface map regeneration. |
| `AWS_PROFILE=root ... make aws-cert-teardown-iam` | passed | Removed the previous bootstrap IAM material from the root boundary. |
| `AWS_PROFILE=root AWS_CERT_BUDGET_LIMIT_USD=750 AWS_CERT_BUDGET_NAME=yield-control-plane-cert-750-usd ... make aws-cert-bootstrap-iam` | passed | Created or verified the explicit `$750` guardrail and minted fresh temporary scoped role credentials. |
| `source artifacts/aws-certification/aws-cert-temp-role.env && make aws-cert-preflight` | passed | Preflight recorded non-root assumed-role identity, `us-west-2`, budget `yield-control-plane-cert-750-usd`, limit `$750`, actual `$650.121`, forecast `$1179.916`, and 24-hour TTL. |
| `gh run watch 27708999746`; `gh run view 27708999746 --job 81964884829 --log` | failed then diagnosed | Integration CI passed; static CI failed because `ripgrep` was not installed before `make validate` ran `validate-aws-certification.sh`. |

## Files Changed

Runtime config, messaging boundary, worker queue resolution, AWS simulation IaC, certifier crate, k6 workload, certification scripts, docs, Makefile/justfile targets, `.dockerignore`, and repo surface coverage map.

## Boundary Audit

No real AWS commands are run by `make validate` or `make validate-aws-certification`. Real AWS commands require explicit opt-in and preflight. Root is used only for bootstrap and teardown. Build contexts must exclude credential/evidence artifacts before image builds.

## Validation Results

Passed locally before live execution, including OpenTofu formatting validation. The formal admission gates and full `make validate` gate now pass before rebuild. The matching `$750` budget cap is configured and preflight records actual spend within that cap. Cleanup/root teardown and final local validation remain allowed.

## Audit Closure

Open. AWS campaign execution remains in progress and must not be marked internally certified until deploy, workload, collect, destroy, bootstrap teardown, and final generated-map validation pass.

## Known Follow-Ups

Commit and push the CI `ripgrep` fix, monitor replacement CI until green, then run deploy, workload, collect, destroy, root teardown, and final validation.
