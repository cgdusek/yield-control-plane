#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification commands" >&2
  exit 1
fi

for tool in aws jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required" >&2
    exit 1
  }
done

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"
outputs_path="$ARTIFACT_DIR/tofu-outputs.json"

AWS_CERT_BUDGET_SPEND_MODE=cleanup ./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-collect.json" >/dev/null

git_sha="$(git rev-parse HEAD)"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg generated_at "$generated_at" \
  --arg git_sha "$git_sha" \
  --arg api_base_url "${API_BASE_URL:-}" \
  '{
    generated_at: $generated_at,
    git_sha: $git_sha,
    api_base_url: $api_base_url,
    commands: [
      "make validate",
      "RUN_DATABASE_TESTS=1 DATABASE_URL=... cargo test -p institutional-yield-persistence --all-features",
      "make smoke",
      "make smoke-failure-paths",
      "make aws-cert-preflight",
      "make aws-cert-deploy",
      "make aws-cert-run",
      "make aws-cert-collect"
    ]
  }' > "$ARTIFACT_DIR/command-manifest.json"

identity_json="$(aws sts get-caller-identity --output json)"
printf '%s\n' "$identity_json" > "$ARTIFACT_DIR/aws-identity.json"

if [[ -f "$outputs_path" ]]; then
  cluster="$(jq -r '.ecs_cluster_name.value // empty' "$outputs_path")"
  if [[ -n "$cluster" ]]; then
    aws ecs describe-clusters --clusters "$cluster" --output json > "$ARTIFACT_DIR/ecs-cluster.json"
    aws ecs list-services --cluster "$cluster" --output json > "$ARTIFACT_DIR/ecs-services.json"
  fi
  jq -r '.worker_queue_urls.value | to_entries[] | [.key, .value] | @tsv' "$outputs_path" | while IFS=$'\t' read -r name url; do
    aws sqs get-queue-attributes \
      --queue-url "$url" \
      --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
      --output json > "$ARTIFACT_DIR/sqs-${name}.json"
  done
  if [[ -f "$ARTIFACT_DIR/queue-drain-post-fis.json" ]]; then
    cp "$ARTIFACT_DIR/queue-drain-post-fis.json" "$ARTIFACT_DIR/queue-drain-final.json"
  else
    if AWS_CERT_BUDGET_SPEND_MODE=cleanup AWS_CERT_QUEUE_DRAIN_STAGE="collect" ./scripts/aws-cert-wait-queues-drained.sh; then
      cp "$ARTIFACT_DIR/queue-drain-collect.json" "$ARTIFACT_DIR/queue-drain-final.json"
    else
      cp "$ARTIFACT_DIR/queue-drain-collect.json" "$ARTIFACT_DIR/queue-drain-final.json"
      jq \
        '.collection_status = "failed-drain-evidence-retained"' \
        "$ARTIFACT_DIR/queue-drain-final.json" > "$ARTIFACT_DIR/queue-drain-final.json.tmp"
      mv "$ARTIFACT_DIR/queue-drain-final.json.tmp" "$ARTIFACT_DIR/queue-drain-final.json"
    fi
  fi
fi

run_cloud_certifier=false
if [[ -f "$outputs_path" ]] && jq -e '.certifier_task_definition_arn.value and .public_subnet_ids.value and .ecs_security_group_id.value' "$outputs_path" >/dev/null; then
  run_cloud_certifier=true
fi

if [[ "$run_cloud_certifier" == "true" ]]; then
  cluster="$(jq -r '.ecs_cluster_name.value' "$outputs_path")"
  task_definition="$(jq -r '.certifier_task_definition_arn.value' "$outputs_path")"
  log_group="$(jq -r '.certifier_log_group_name.value' "$outputs_path")"
  subnets_json="$(jq -c '.public_subnet_ids.value' "$outputs_path")"
  security_groups_json="$(jq -c '[.ecs_security_group_id.value]' "$outputs_path")"
  network_configuration="$(jq -cn \
    --argjson subnets "$subnets_json" \
    --argjson security_groups "$security_groups_json" \
    '{awsvpcConfiguration:{subnets:$subnets,securityGroups:$security_groups,assignPublicIp:"ENABLED"}}')"
  overrides="$(jq -cn \
    '{containerOverrides:[{name:"certifier",environment:[{name:"AWS_CERT_PROBE_COMPACT",value:"1"}]}]}')"

  aws ecs run-task \
    --cluster "$cluster" \
    --task-definition "$task_definition" \
    --launch-type FARGATE \
    --network-configuration "$network_configuration" \
    --overrides "$overrides" \
    --count 1 \
    --output json > "$ARTIFACT_DIR/certifier-run-task.json"

  certifier_task_arn="$(jq -r '.tasks[0].taskArn // empty' "$ARTIFACT_DIR/certifier-run-task.json")"
  if [[ -z "$certifier_task_arn" ]]; then
    echo "Certifier ECS task did not start; see $ARTIFACT_DIR/certifier-run-task.json" >&2
    exit 1
  fi

  aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$certifier_task_arn"
  aws ecs describe-tasks \
    --cluster "$cluster" \
    --tasks "$certifier_task_arn" \
    --output json > "$ARTIFACT_DIR/certifier-describe-task.json"

  certifier_exit_code="$(jq -r '.tasks[0].containers[] | select(.name == "certifier") | .exitCode // empty' "$ARTIFACT_DIR/certifier-describe-task.json")"
  certifier_task_id="${certifier_task_arn##*/}"
  log_stream="certifier/certifier/${certifier_task_id}"
  for _ in $(seq 1 20); do
    if aws logs get-log-events \
      --log-group-name "$log_group" \
      --log-stream-name "$log_stream" \
      --start-from-head \
      --output json > "$ARTIFACT_DIR/certifier-log-events.json" 2>/dev/null; then
      break
    fi
    sleep 3
  done
  jq -r '.events[].message' "$ARTIFACT_DIR/certifier-log-events.json" > "$ARTIFACT_DIR/db-invariant-report.raw"
  jq -r '.events[].message | select(startswith("{"))' "$ARTIFACT_DIR/certifier-log-events.json" | tail -n 1 > "$ARTIFACT_DIR/db-invariant-report.json"
  if ! jq -e '.checks_failed == 0' "$ARTIFACT_DIR/db-invariant-report.json" >/dev/null; then
    echo "DB invariant certifier failed or produced invalid output; see $ARTIFACT_DIR/db-invariant-report.json" >&2
    exit 1
  fi
  if [[ "$certifier_exit_code" != "0" ]]; then
    echo "Certifier ECS task exited with code $certifier_exit_code; see $ARTIFACT_DIR/certifier-describe-task.json" >&2
    exit 1
  fi
elif [[ -n "${DATABASE_URL:-}" ]]; then
  AWS_CERT_PROBE_OUTPUT="$ARTIFACT_DIR/db-invariant-report.json" \
    cargo run -p institutional-yield-certifier
else
  jq -n '{status:"failed", reason:"No cloud certifier task outputs and DATABASE_URL not exported for local certifier run."}' \
    > "$ARTIFACT_DIR/db-invariant-report.json"
  echo "DB invariant certifier could not run; see $ARTIFACT_DIR/db-invariant-report.json" >&2
  exit 1
fi

start_date="$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d '1 day ago' +%Y-%m-%d)"
end_date="$(date -u +%Y-%m-%d)"
if aws ce get-cost-and-usage \
  --time-period "Start=${start_date},End=${end_date}" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output json > "$ARTIFACT_DIR/cost-summary.json"
then
  :
else
  jq -n '{status:"unavailable", reason:"Cost Explorer permissions or activation missing"}' > "$ARTIFACT_DIR/cost-summary.json"
fi

jq -n \
  --slurpfile command "$ARTIFACT_DIR/command-manifest.json" \
  --slurpfile identity "$ARTIFACT_DIR/aws-identity.json" \
  '{
    command_manifest: $command[0],
    identity: $identity[0],
    evidence_directory: "artifacts/aws-certification"
  }' > "$ARTIFACT_DIR/aws-inventory.json"

echo "AWS certification evidence collected in $ARTIFACT_DIR"
