# AWS Simulation And Internal Certification

This workstream adds an opt-in AWS sandbox simulation and an internal evidence pack. It does not claim SOC, ISO, regulatory, legal, investment, accounting, tax, production-deployment, or transfer-agent certification.

Broader SOC, ISO, PCI, CSA, NIST, CIS, AWS, US regulatory, EU regulatory, UK regulatory, and production-adjacent readiness mapping is tracked in [Standards and certification readiness](compliance-readiness.md) and [standards_readiness_map.json](../spec/certification/standards_readiness_map.json).

AWS sandbox data flows, trust boundaries, data classifications, and control mappings are tracked in the [DFD evidence pack](security/dfd/README.md).
AWS sandbox C4 containers, relationships, and source evidence are tracked in the [C4 evidence pack](architecture/c4/README.md).

The local runtime remains LocalStack-only. Real AWS execution is isolated behind `AWS_CERTIFICATION_ENABLED=1`, `APP_ENV=cert`, `AWS_REGION=us-west-2`, and a preflight that rejects root identity, wrong region, missing budget guardrails, exceeded budget spend, and missing teardown TTL tags. Root is used only for one-time sandbox bootstrap or break-glass recovery; deployment, workload, collection, and teardown run through a temporary scoped role.

## Standards Basis

The evidence pack maps controls to these public references:

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Financial Services Industry Lens](https://docs.aws.amazon.com/wellarchitected/latest/financial-services-industry-lens/financial-services-industry-lens.html)
- [AWS root user best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html)
- [AWS IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Amazon ECS Fargate capacity providers](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-capacity-providers.html)
- [AWS FIS experiment planning](https://docs.aws.amazon.com/fis/latest/userguide/getting-started-planning.html)
- [AWS FIS actions reference](https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html)
- [Amazon SQS dead-letter queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)
- [Amazon SNS topic encryption with encrypted SQS subscriptions](https://docs.aws.amazon.com/sns/latest/dg/sns-enable-encryption-for-topic-sqs-queue-subscriptions.html)
- [Amazon SQS least-privilege encrypted queue policies](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-least-privilege-policy.html)
- [NIST CSF 2.0](https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.29.pdf)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)

The completed campaign report is [AWS simulation internal certification report - 2026-06-17](certification/aws-simulation-internal-certification-report-2026-06-17.md).

## Control Rationale

| Control Area | Implementation Evidence |
| --- | --- |
| Root account avoidance | `scripts/aws-cert-bootstrap-iam.sh` uses root only to create or verify the budget, create an ephemeral IAM bridge user, and mint temporary scoped role credentials; `scripts/aws-cert-preflight.sh` rejects root caller identity; deploy, run, collect, and destroy all invoke preflight. |
| Least privilege runtime | ECS task roles publish to the certification SNS topic, consume named SQS queues, and decrypt only the simulation KMS key and database secret. |
| Cost boundary | Bootstrap creates or verifies the configured budget, preflight rejects deploy/run work when the budget's actual spend exceeds the configured limit, destroy detaches the imported budget before workload teardown, and `AWS_CERT_TTL_HOURS` is required so resources carry teardown tags. The default is `$50`; `AWS_CERT_BUDGET_LIMIT_USD` is an explicit override for a bounded rerun when prior account-month spend already exceeds the default. Collect/destroy use cleanup mode so an over-budget state cannot strand resources. Root teardown deletes the budget only if bootstrap created it. |
| Fargate Spot resilience | Worker services use `FARGATE_SPOT` plus `FARGATE`; API and mock control surfaces keep an On-Demand floor. The stack avoids ECS placement strategies because they are not supported by the Fargate launch type used here. |
| Queue safety | SQS queues have DLQs, visibility timeout, KMS encryption, SNS queue policies, raw message delivery, CloudWatch DLQ alarms, and KMS key policy access for the SNS service principal to deliver into encrypted queues. |
| First-use AWS services | Bootstrap verifies the FIS service-linked role before run time so fault injection cannot fail after the k6 campaign. The temporary runner role can create the service-linked roles and private DNS resources required by ECS, ELB, RDS, and Cloud Map in the sandbox; the ECS service-linked role is explicitly modeled in OpenTofu, and tag permissions are scoped to that service-linked role ARN for provider reconciliation. |
| Log encryption | The simulation KMS key policy grants the regional CloudWatch Logs service encryption rights only for `/ecs/<workload>/*` log groups. |
| Fault injection | The FIS template stops one ECS worker task to exercise at-least-once delivery, inbox dedupe, outbox retry, and task replacement. ECS services propagate service tags to tasks, and `scripts/aws-cert-check-fis-targets.sh` proves that tagged worker task targets exist before load and before the FIS experiment starts. |
| Financial invariants | `institutional-yield-certifier` verifies idempotency, confirmation uniqueness, one position per order, reconciled history, ledger balance, append-only ledger, inbox dedupe, outbox duplication, and stale unpublished events. |
| Async completion evidence | `scripts/aws-cert-wait-queues-drained.sh` checks source queues and DLQs before the campaign, after smoke, after k6, after FIS, and during collection if needed. Certification fails if visible, in-flight, delayed, or DLQ messages remain at the drain gate. |
| ECS replacement evidence | `scripts/aws-cert-wait-ecs-services-stable.sh` waits for ECS services to stabilize before smoke and after FIS stop-task experiments. |
| Evidence retention | `scripts/aws-cert-collect.sh` writes command, AWS inventory, queue, cost, FIS, k6, DB invariant, certifier task, and queue-drain JSON under `artifacts/aws-certification/`. |
| Build-context hygiene | `.dockerignore` excludes `artifacts/`, OpenTofu state, environment files, private keys, local caches, and TLA generated state; `make validate-aws-certification` and `make aws-cert-deploy` enforce this before Docker builds. |

## Acceptance

The AWS workstream is accepted only when all of these pass:

```bash
make validate
RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features
make smoke
make smoke-failure-paths
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-preflight
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-admission-check
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-deploy
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-run
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-wait-queues-drained
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-collect
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-destroy
```

When starting from sandbox root credentials, first run `make aws-cert-bootstrap-iam`, source `artifacts/aws-certification/aws-cert-temp-role.env`, and then run the campaign commands. After infrastructure teardown, return to root only for `make aws-cert-teardown-iam`.

If a Docker build starts before the build context excludes `artifacts/`, cancel the deploy, destroy any partial AWS infrastructure, tear down the bootstrap IAM material, and bootstrap fresh temporary credentials. The final runtime images copy only service binaries, but the certification process treats over-broad build context exposure as a failed hygiene gate.

The local static acceptance gate is:

```bash
make validate-aws-certification
make validate-dfd
make validate-c4
```

Formal admission evidence for the cloud campaign is recorded in [AWS certification formal diagnosis](trackers/aws-certification-formal-diagnosis.md).
