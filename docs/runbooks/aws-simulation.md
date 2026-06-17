# AWS Simulation Runbook

Use this runbook only with a dedicated non-production AWS sandbox account. Do not use production accounts, production transfer-agent integrations, real customer data, root credentials, or long-lived runtime credentials.

## Root Bootstrap Boundary

Root is used only to establish the sandbox controls that make the rest of the demo credible:

1. Enable MFA on the sandbox root user and remove root access keys.
2. Create or verify the configured budget. The default is the `$50` budget named `yield-control-plane-cert-50-usd`.
3. Create the temporary scoped deployment role used for the campaign.
4. Configure CloudTrail or account-level audit logging if the sandbox does not already inherit it.
5. Leave root and run every command below through the scoped role.

The certification scripts reject root for deploy, run, collect, and destroy. Deploy and run also reject an exceeded configured budget. Collect and destroy use cleanup mode for the budget-spend check so an over-budget or failed campaign can still retain evidence and tear down resources.

The CLI bootstrap path is:

```bash
export AWS_CERTIFICATION_ENABLED=1
export AWS_REGION=us-west-2
export AWS_DEFAULT_REGION=us-west-2
export AWS_CERT_TTL_HOURS=24
export AWS_CERT_BUDGET_NAME=yield-control-plane-cert-50-usd
export AWS_CERT_BUDGET_LIMIT_USD=50

make aws-cert-bootstrap-iam
```

The bootstrap command must run as the sandbox root identity. It creates or verifies the configured budget, creates an ephemeral IAM bridge user, creates a scoped `yield-control-plane-cert-runner-*` role, uses the bridge user to assume that role, and writes temporary role credentials to `artifacts/aws-certification/aws-cert-temp-role.env`. AWS root accounts cannot assume roles directly, so the short-lived bridge user is the executable handoff from root bootstrap to scoped role execution.

If bootstrap is rerun for the same ephemeral bridge user during a failed campaign remediation, it deletes that user's existing access keys before issuing a replacement key. This prevents orphaned bootstrap-user credentials when the runner role policy needs to be updated mid-campaign.

The bootstrap artifacts include temporary secrets under `artifacts/aws-certification/`. That directory is ignored by git. Do not copy those files into docs, tickets, chat, commits, or CI variables.

The Docker build context must also exclude these artifacts. `make validate-aws-certification` checks `.dockerignore` for `artifacts/`, OpenTofu state, environment files, private keys, local caches, and generated TLA state, and `make aws-cert-deploy` reruns that static gate before building images. If a deploy is started with an over-broad context, cancel it, destroy any partial infrastructure with the temporary role, run root teardown, and bootstrap new temporary credentials before retrying.

After bootstrap, leave root by sourcing the temporary role credentials:

```bash
source artifacts/aws-certification/aws-cert-temp-role.env
aws sts get-caller-identity
```

The returned ARN must be an assumed-role ARN, not `arn:aws:iam::*:root`.

## Prerequisites

```bash
aws sts get-caller-identity
docker info
make validate-aws-certification
```

Required environment:

```bash
export AWS_CERTIFICATION_ENABLED=1
export AWS_REGION=us-west-2
export AWS_CERT_TTL_HOURS=24
export AWS_CERT_ACCOUNT_ID=<sandbox-account-id>
export AWS_CERT_BUDGET_NAME=yield-control-plane-cert-50-usd
export AWS_CERT_BUDGET_LIMIT_USD=50
```

If the account-month AWS Budget already reports spend above `$50` and a bounded rerun is explicitly authorized, set a matching higher budget name and limit before root bootstrap. For the current rerun path, use:

```bash
export AWS_CERT_BUDGET_LIMIT_USD=750
export AWS_CERT_BUDGET_NAME=yield-control-plane-cert-750-usd
```

The override must appear in `artifacts/aws-certification/preflight.json`, and deploy/run remain blocked if actual spend exceeds that configured limit.

## Local Baseline

```bash
make validate
make dev-reset
make dev-up
RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features
make smoke
make smoke-failure-paths
make dev-down
```

## AWS Campaign

```bash
source artifacts/aws-certification/aws-cert-temp-role.env
make aws-cert-preflight
make aws-cert-deploy
make aws-cert-run
make aws-cert-collect
make aws-cert-destroy
```

For infra-only remediation after the four service images have already been pushed for the current git SHA, the deploy can skip Docker rebuilds while still verifying that each ECR image tag exists:

```bash
AWS_CERT_SKIP_IMAGE_BUILD=1 make aws-cert-deploy
```

If any step fails, collect the available evidence and destroy the stack:

```bash
make aws-cert-collect
make aws-cert-destroy
```

If the failure occurred before the workload was reachable, collection may not have all evidence files. If queue drain fails, collection keeps `queue-drain-final.json` with `collection_status: failed-drain-evidence-retained` and still continues to the remaining evidence files. In either case, record the missing or failed evidence as a failed scenario, destroy the partial stack, and do not claim internal certification success.

First-use sandbox accounts may need AWS-created service-linked roles for ECS, Elastic Load Balancing, and RDS, plus a Route 53 private hosted zone for Cloud Map. The ECS service-linked role is modeled in OpenTofu; the others may be created implicitly by their services. Those permissions belong to the temporary runner role because they are part of bootstrapping the certification stack, not to root after the handoff. The runner role also has narrowly scoped tag permissions for the ECS service-linked role because the OpenTofu provider applies default tags during reconciliation.

Worker services run on `FARGATE_SPOT` with an On-Demand fallback. Fargate services in this stack do not use `ordered_placement_strategy`; subnet spreading comes from the VPC subnet set and ECS/Fargate scheduling. If a deploy fails on placement-strategy support, remove the strategy from the service and make the static validator reject reintroduction.

If the ECS service-linked role is created but the provider fails while applying tags, OpenTofu may mark `aws_iam_service_linked_role.ecs` as tainted. After fixing the scoped tag permission, untaint that resource before retrying so OpenTofu reconciles the existing AWS-managed role instead of trying to replace a role that active ECS services may already use:

```bash
cd infra/aws-simulation
tofu untaint aws_iam_service_linked_role.ecs
```

If smoke creates an order but it remains `Created`, check `AWS/SNS NumberOfNotificationsFailed` for the domain-events topic. A count equal to the number of SQS subscriptions usually means encrypted fanout failed before workers received messages. The simulation KMS key must allow `sns.amazonaws.com` to call `kms:GenerateDataKey*` and `kms:Decrypt` for this topic, and each SQS subscription must use raw message delivery because workers parse the body directly as the domain `EventEnvelope`.

`make aws-cert-run` gates every async phase with queue-drain evidence. It runs the drain check before workload start, after smoke, after k6, after FIS, and `make aws-cert-collect` records `queue-drain-final.json`. A failed drain is a failed certification run, even if k6 thresholds pass, because unprocessed source messages or DLQ messages mean the asynchronous control plane has not proven completion. The drain gate uses SQS queue attributes for visible, in-flight, and delayed counts; oldest-message-age review belongs in CloudWatch metric evidence.

The k6 campaign uses a 30-minute constant-arrival-rate profile by default. `CERT_TARGET_ATTEMPTS=1000` and `CERT_DURATION=30m` derive a per-minute arrival rate, `CERT_VUS=25` caps allocated VUs, and `CERT_RATE_PER_MINUTE` can override the rate for a deliberate stress run. `make aws-cert-admission-check` records `admission-check.json` and fails before k6 if target attempts, scheduled iterations, or arrival rate exceed the configured caps. The script sets expected HTTP statuses so intentional 409 idempotency conflicts and 422 FIDD-yield rejections do not count as request failures, while unexpected 5xx responses still fail the `http_req_failed` threshold.

After FIS stops a worker task, `make aws-cert-run` waits for all ECS services to stabilize before the post-FIS queue drain. During collection, `make aws-cert-collect` runs the certifier as a one-off ECS task when cloud outputs are available and fails if `db-invariant-report.json` is missing or reports failed checks.

`make aws-cert-destroy` removes the imported budget from local OpenTofu state before destroying workload resources. That keeps the budget as a bootstrap guardrail rather than a normal workload resource. The root teardown script deletes the budget only when the bootstrap state says this campaign created it.

## Evidence Review

Review these files:

```bash
jq . artifacts/aws-certification/preflight.json
jq . artifacts/aws-certification/admission-check.json
jq . artifacts/aws-certification/k6-summary.json
jq . artifacts/aws-certification/queue-drain-final.json
jq . artifacts/aws-certification/db-invariant-report.json
jq . artifacts/aws-certification/aws-inventory.json
jq . artifacts/aws-certification/cost-summary.json
```

Certification success requires zero failed DB invariant checks, passing k6 thresholds, empty SQS source queues after drain, empty DLQs unless the test intentionally injected poison messages, and total campaign cost within the configured guardrail.

## Teardown

```bash
make aws-cert-destroy
```

After teardown, confirm the ECS cluster, RDS instance, SQS queues, SNS topic, and ALB are gone from the sandbox account.

Finally, return to root only to remove bootstrap IAM material created for the campaign:

```bash
export AWS_CERTIFICATION_ENABLED=1
export AWS_REGION=us-west-2
export AWS_DEFAULT_REGION=us-west-2
make aws-cert-teardown-iam
```

Teardown deletes the bridge user access key and inline policy. It also deletes the bridge user, runner role, and budget only when the bootstrap state records that those resources were created by this campaign.
