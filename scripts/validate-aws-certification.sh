#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_files=(
  "docs/aws-certification.md"
  "docs/runbooks/aws-simulation.md"
  "docs/trackers/aws-certification-simulation-planning.md"
  "docs/trackers/aws-certification-simulation-implementation.md"
  "docs/trackers/aws-certification-simulation-tracking.md"
  "docs/trackers/aws-certification-formal-diagnosis.md"
  "spec/certification/aws_certification_coverage_map.json"
  "spec/certification/aws_certification_load.js"
  "spec/tla/YieldCertificationCapacity.tla"
  "spec/tla/YieldCertificationCapacityProofs.tla"
  "spec/tla/YieldCertificationCapacity.cfg"
  ".dockerignore"
  "infra/aws-simulation/versions.tf"
  "infra/aws-simulation/variables.tf"
  "infra/aws-simulation/main.tf"
  "infra/aws-simulation/outputs.tf"
  "scripts/aws-cert-preflight.sh"
  "scripts/aws-cert-bootstrap-iam.sh"
  "scripts/aws-cert-deploy.sh"
  "scripts/aws-cert-run.sh"
  "scripts/aws-cert-collect.sh"
  "scripts/smoke-create-sweep.sh"
  "scripts/aws-cert-admission-check.sh"
  "scripts/aws-cert-wait-queues-drained.sh"
  "scripts/aws-cert-wait-ecs-services-stable.sh"
  "scripts/aws-cert-check-fis-targets.sh"
  "scripts/aws-cert-destroy.sh"
  "scripts/aws-cert-teardown-iam.sh"
  "services/certifier/Cargo.toml"
  "services/certifier/src/main.rs"
  "crates/domain/src/certification.rs"
)

for path in "${required_files[@]}"; do
  [[ -f "$path" ]] || {
    echo "missing required AWS certification artifact: $path" >&2
    exit 1
  }
done

required_dockerignore_patterns=(
  '^artifacts/?$'
  '^\*\*/?\.terraform$|^\.terraform$|^\*\*/\.terraform$'
  '^\*\.tfstate$'
  '^\*\.tfstate\.\*$'
  '^\.env$'
  '^\.env\.\*$'
  '^\.git$'
  '^target$'
)

for pattern in "${required_dockerignore_patterns[@]}"; do
  rg -q "$pattern" .dockerignore || {
    echo ".dockerignore must exclude sensitive or oversized path pattern: $pattern" >&2
    exit 1
  }
done

for script in \
  scripts/aws-cert-preflight.sh \
  scripts/aws-cert-bootstrap-iam.sh \
  scripts/aws-cert-deploy.sh \
  scripts/aws-cert-run.sh \
  scripts/aws-cert-collect.sh \
  scripts/aws-cert-admission-check.sh \
  scripts/aws-cert-wait-queues-drained.sh \
  scripts/aws-cert-wait-ecs-services-stable.sh \
  scripts/aws-cert-check-fis-targets.sh \
  scripts/aws-cert-destroy.sh \
  scripts/aws-cert-teardown-iam.sh
do
  [[ -x "$script" ]] || {
    echo "$script must be executable" >&2
    exit 1
  }
  rg -q "AWS_CERTIFICATION_ENABLED" "$script" || {
    echo "$script must enforce AWS_CERTIFICATION_ENABLED" >&2
    exit 1
  }
done

python3 - <<'PY'
import json
from pathlib import Path

coverage = json.loads(Path("spec/certification/aws_certification_coverage_map.json").read_text())
assert coverage["defaults"]["aws_region"] == "us-west-2"
assert coverage["defaults"]["budget_limit_usd"] == 50
assert coverage["defaults"]["budget_limit_override_env"] == "AWS_CERT_BUDGET_LIMIT_USD"
assert coverage["defaults"]["root_user_policy"] == "root_bootstrap_or_break_glass_only"
required = {
    "aws_identity_and_budget_guardrails",
    "ecs_runtime",
    "real_sns_sqs_messaging",
    "rds_postgres_financial_state",
    "load_and_fault_simulation",
    "evidence_pack",
}
surfaces = {surface["id"] for surface in coverage["surfaces"]}
missing = required - surfaces
assert not missing, f"missing surfaces: {sorted(missing)}"
assert len(coverage["standards_basis"]) >= 10
assert "fis_ecs_stop_task" in coverage["required_scenarios"]
assert "artifacts/aws-certification/db-invariant-report.json" in coverage["required_evidence_outputs"]
assert "artifacts/aws-certification/queue-drain-final.json" in coverage["required_evidence_outputs"]
assert "artifacts/aws-certification/admission-check.json" in coverage["required_evidence_outputs"]
PY

rg -q 'variable "budget_limit_usd"' infra/aws-simulation/variables.tf
rg -q 'variable "runtime_cpu_architecture"' infra/aws-simulation/variables.tf
rg -q 'default     = 50' infra/aws-simulation/variables.tf
rg -q 'default     = "us-west-2"' infra/aws-simulation/variables.tf
rg -q 'default     = "ARM64"' infra/aws-simulation/variables.tf
rg -q 'FARGATE_SPOT' infra/aws-simulation/main.tf
! rg -q 'ordered_placement_strategy' infra/aws-simulation/main.tf || {
  echo "Fargate services must not configure ECS placement strategies" >&2
  exit 1
}
rg -q 'cpu_architecture        = var.runtime_cpu_architecture' infra/aws-simulation/main.tf
rg -q 'aws_iam_service_linked_role" "ecs"' infra/aws-simulation/main.tf
rg -q 'aws_ecs_cluster_capacity_providers.main' infra/aws-simulation/main.tf
rg -q 'aws_fis_experiment_template' infra/aws-simulation/main.tf
rg -q 'propagate_tags  = "SERVICE"' infra/aws-simulation/main.tf
rg -q 'enable_ecs_managed_tags = true' infra/aws-simulation/main.tf
rg -q 'aws_budgets_budget' infra/aws-simulation/main.tf
rg -q 'aws_sqs_queue" "dlq"' infra/aws-simulation/main.tf
rg -q 'recovery_window_in_days = 0' infra/aws-simulation/main.tf
rg -q 'AllowCloudWatchLogsEncryption' infra/aws-simulation/main.tf
rg -q 'AllowSnsToSendToEncryptedSqs' infra/aws-simulation/main.tf
rg -q 'raw_message_delivery = true' infra/aws-simulation/main.tf
rg -q 'arn:aws:iam::\\*\\*root|:root|root' scripts/aws-cert-preflight.sh
rg -q 'AWS_CERT_BUDGET_LIMIT_USD:-50' scripts/aws-cert-preflight.sh
rg -q 'AWS_CERT_BUDGET_SPEND_MODE' scripts/aws-cert-preflight.sh
rg -q 'actual spend.*exceeds limit' scripts/aws-cert-preflight.sh
rg -q 'budget_actual_spend_usd' scripts/aws-cert-preflight.sh
rg -q 'AWS_CERT_BUDGET_LIMIT_USD:-50' scripts/aws-cert-bootstrap-iam.sh
rg -q 'export AWS_CERT_BUDGET_LIMIT_USD' scripts/aws-cert-bootstrap-iam.sh
rg -q 'AWS_CERT_BUDGET_SPEND_MODE=cleanup.*preflight-collect.json' scripts/aws-cert-collect.sh
rg -q 'AWS_CERT_BUDGET_SPEND_MODE=cleanup.*preflight-destroy.json' scripts/aws-cert-destroy.sh
rg -q 'bootstrap must run from the sandbox root identity' scripts/aws-cert-bootstrap-iam.sh
rg -q 'aws sts assume-role' scripts/aws-cert-bootstrap-iam.sh
rg -q 'create-user' scripts/aws-cert-bootstrap-iam.sh
rg -q 'create-access-key' scripts/aws-cert-bootstrap-iam.sh
rg -q 'list-access-keys' scripts/aws-cert-bootstrap-iam.sh
rg -q 'delete-access-key' scripts/aws-cert-bootstrap-iam.sh
rg -q 'budgets:ModifyBudget' scripts/aws-cert-bootstrap-iam.sh
rg -q 'iam:CreateServiceLinkedRole' scripts/aws-cert-bootstrap-iam.sh
rg -q 'AWSServiceRoleForECS' scripts/aws-cert-bootstrap-iam.sh
rg -q 'create-service-linked-role' scripts/aws-cert-bootstrap-iam.sh
rg -q 'fis.amazonaws.com' scripts/aws-cert-bootstrap-iam.sh
rg -q 'AWSServiceRoleForFIS' scripts/aws-cert-bootstrap-iam.sh
rg -q 'FisServiceLinkedRoleRead' scripts/aws-cert-bootstrap-iam.sh
rg -q 'iam:TagRole' scripts/aws-cert-bootstrap-iam.sh
rg -q 'iam:DeleteServiceLinkedRole' scripts/aws-cert-bootstrap-iam.sh
rg -q 'ServiceLinkedRoleDeletionStatus' scripts/aws-cert-bootstrap-iam.sh
rg -q 'iam:ListInstanceProfilesForRole' scripts/aws-cert-bootstrap-iam.sh
rg -q 'iam:ListAttachedRolePolicies' scripts/aws-cert-bootstrap-iam.sh
rg -q 'route53:CreateHostedZone' scripts/aws-cert-bootstrap-iam.sh
rg -q 'required FIS service-linked role is missing' scripts/aws-cert-preflight.sh
rg -q 'fis_service_linked_role_arn' scripts/aws-cert-preflight.sh
rg -q 'delete-access-key' scripts/aws-cert-teardown-iam.sh
rg -q 'state rm aws_budgets_budget.campaign' scripts/aws-cert-destroy.sh
rg -q 'aws_budgets_budget.campaign' scripts/aws-cert-deploy.sh
rg -Fq 'budget_limit_usd="${AWS_CERT_BUDGET_LIMIT_USD:-50}"' scripts/aws-cert-deploy.sh
rg -Fq 'budget_limit_usd="${AWS_CERT_BUDGET_LIMIT_USD:-50}"' scripts/aws-cert-destroy.sh
rg -q 'AWS_CERT_IMAGE_PLATFORM:-linux/arm64' scripts/aws-cert-deploy.sh
rg -q 'AWS_CERT_SKIP_IMAGE_BUILD' scripts/aws-cert-deploy.sh
rg -q 'describe-images' scripts/aws-cert-deploy.sh
rg -q 'AWS_CERT_FORCE_ECS_DEPLOYMENT' scripts/aws-cert-deploy.sh
rg -q 'force-new-deployment' scripts/aws-cert-deploy.sh
rg -q 'validate-aws-certification.sh' scripts/aws-cert-deploy.sh
rg -q 'aws-cert-preflight.sh.*preflight-run.json' scripts/aws-cert-run.sh
rg -q 'aws-cert-admission-check.sh' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_FIS_TARGET_STAGE="pre-run"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_FIS_TARGET_STAGE="pre-fis"' scripts/aws-cert-run.sh
rg -q 'aws-cert-check-fis-targets.sh' scripts/aws-cert-run.sh
rg -q 'describe-tasks' scripts/aws-cert-check-fis-targets.sh
rg -q -- '--include TAGS' scripts/aws-cert-check-fis-targets.sh
rg -q 'CertificationWorkstream' scripts/aws-cert-check-fis-targets.sh
rg -q 'WorkerKind' scripts/aws-cert-check-fis-targets.sh
rg -q 'POLICY_KEY=.*smoke-policy' scripts/smoke-create-sweep.sh
rg -Fq '[.[] | select(.order_id == $order)] | length' scripts/smoke-create-sweep.sh
rg -q 'aws-cert-preflight.sh.*preflight-collect.json' scripts/aws-cert-collect.sh
rg -q 'AWS_CERT_QUEUE_DRAIN_STAGE="pre-run"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_QUEUE_DRAIN_STAGE="post-smoke"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_QUEUE_DRAIN_STAGE="post-k6"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_QUEUE_DRAIN_STAGE="post-fis"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_ECS_STABILITY_STAGE="post-fis"' scripts/aws-cert-run.sh
rg -q 'AWS_CERT_FIS_TIMEOUT_SECONDS' scripts/aws-cert-run.sh
rg -q 'queue-drain-final.json' scripts/aws-cert-collect.sh
rg -q 'ecs run-task' scripts/aws-cert-collect.sh
rg -q 'certifier_task_definition_arn' scripts/aws-cert-collect.sh
rg -q 'GIT_SHA' scripts/aws-cert-collect.sh
rg -q 'GIT_SHA' services/certifier/src/main.rs
rg -q 'db-invariant-report.json' scripts/aws-cert-collect.sh
! rg -q 'status:"skipped"|status:"skipped"' scripts/aws-cert-collect.sh || {
  echo "AWS certification collection must not skip DB invariant certifier evidence" >&2
  exit 1
}
rg -q 'failed-drain-evidence-retained' scripts/aws-cert-collect.sh
rg -q 'ApproximateNumberOfMessagesDelayed' scripts/aws-cert-wait-queues-drained.sh
! rg -q 'ApproximateAgeOfOldestMessage' scripts/aws-cert-wait-queues-drained.sh scripts/aws-cert-collect.sh || {
  echo "SQS GetQueueAttributes does not support ApproximateAgeOfOldestMessage; use CloudWatch metrics for oldest age" >&2
  exit 1
}
rg -q 'worker_dlq_urls' scripts/aws-cert-wait-queues-drained.sh
rg -q 'preflight-queue-drain' scripts/aws-cert-wait-queues-drained.sh
rg -q 'services-stable' scripts/aws-cert-wait-ecs-services-stable.sh
rg -q 'ecs-services-stability' scripts/aws-cert-wait-ecs-services-stable.sh
rg -Fq '[.key, .value] | @tsv' scripts/aws-cert-collect.sh
rg -q 'AWS_CERT_MAX_ARRIVAL_RATE_PER_MINUTE' scripts/aws-cert-admission-check.sh
rg -q 'AWS_CERT_MAX_SCHEDULED_ITERATIONS' scripts/aws-cert-admission-check.sh
rg -q 'admission-check.json' scripts/aws-cert-admission-check.sh
rg -q 'CERT_VUS || "25"' spec/certification/aws_certification_load.js
rg -q 'CERT_DURATION || "30m"' spec/certification/aws_certification_load.js
rg -q 'CERT_TARGET_ATTEMPTS || "1000"' spec/certification/aws_certification_load.js
rg -q 'CERT_RUN_ID' spec/certification/aws_certification_load.js
rg -q 'CERT_RATE_PER_MINUTE' spec/certification/aws_certification_load.js
rg -q 'expectedStatuses' spec/certification/aws_certification_load.js
rg -q 'constant-arrival-rate' spec/certification/aws_certification_load.js
rg -q 'timeUnit: "1m"' spec/certification/aws_certification_load.js
rg -Fq 'iterations: [`count>=${targetAttempts}`]' spec/certification/aws_certification_load.js
rg -q 'Admissible' spec/tla/YieldCertificationCapacity.tla
rg -Fq 'WF_vars(StartCampaign)' spec/tla/YieldCertificationCapacity.tla
rg -q 'AcceptedCampaignEventuallyCompletes' spec/tla/YieldCertificationCapacity.tla
rg -q 'StartCampaignImpliesAdmissionSafety' spec/tla/YieldCertificationCapacityProofs.tla
rg -q 'DirtyQueueBlocksAdmission' spec/tla/YieldCertificationCapacityProofs.tla
rg -q 'SPECIFICATION Spec' spec/tla/YieldCertificationCapacity.cfg
rg -q 'admit_certification_campaign' crates/domain/src/certification.rs
rg -q 'over_budget_blocks_enforced_campaign' crates/domain/src/certification.rs
rg -q 'dirty_queue_is_reported_when_budget_allows_start' crates/domain/src/certification.rs
rg -q 'positive_capacity_eventually_drains_bounded_queue' crates/domain/src/certification.rs
rg -q 'YieldCertificationCapacityProofs.tla' scripts/validate-tla.sh
rg -q 'YieldCertificationCapacity.cfg' scripts/validate-tla.sh
rg -q 'S0-S6' docs/trackers/aws-certification-formal-diagnosis.md
rg -q 'make validate-source-proofs' docs/trackers/aws-certification-formal-diagnosis.md
rg -q 'queue.*capacity' docs/trackers/aws-certification-formal-diagnosis.md

if command -v tofu >/dev/null 2>&1; then
  tofu fmt -check -recursive infra/aws-simulation
elif command -v opentofu >/dev/null 2>&1; then
  opentofu fmt -check -recursive infra/aws-simulation
else
  echo "OpenTofu not installed; skipped tofu fmt static check"
fi

echo "AWS certification static validation passed."
