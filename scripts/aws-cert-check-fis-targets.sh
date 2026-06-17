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
    echo "$tool is required for aws-cert-check-fis-targets" >&2
    exit 1
  }
done

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"

outputs_path="$ARTIFACT_DIR/tofu-outputs.json"
if [[ ! -f "$outputs_path" ]]; then
  echo "$outputs_path is required for FIS target validation" >&2
  exit 1
fi

stage="${AWS_CERT_FIS_TARGET_STAGE:-manual}"
cluster="$(jq -r '.ecs_cluster_name.value // empty' "$outputs_path")"
if [[ -z "$cluster" ]]; then
  echo "ecs_cluster_name output is required for FIS target validation" >&2
  exit 1
fi

./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-fis-targets-${stage}.json" >/dev/null

tag_key="${AWS_CERT_FIS_TARGET_TAG_KEY:-CertificationWorkstream}"
tag_value="${AWS_CERT_FIS_TARGET_TAG_VALUE:-aws-simulation}"
worker_services=(outbox-publisher transfer-agent reconciliation chain-watcher notification)
records_jsonl="$(mktemp)"
empty_services_jsonl="$(mktemp)"
trap 'rm -f "$records_jsonl" "$empty_services_jsonl"' EXIT

for service in "${worker_services[@]}"; do
  mapfile -t task_arns < <(
    aws ecs list-tasks \
      --cluster "$cluster" \
      --service-name "$service" \
      --desired-status RUNNING \
      --output json | jq -r '.taskArns[]?'
  )

  if (( ${#task_arns[@]} == 0 )); then
    jq -n --arg service "$service" '{service: $service, reason: "no-running-tasks"}' >> "$empty_services_jsonl"
    continue
  fi

  aws ecs describe-tasks \
    --cluster "$cluster" \
    --tasks "${task_arns[@]}" \
    --include TAGS \
    --output json |
    jq -c --arg service "$service" \
      '.tasks[] | {service: $service, taskArn, group, lastStatus, desiredStatus, tags}' \
      >> "$records_jsonl"
done

jq -s \
  --arg stage "$stage" \
  --arg cluster "$cluster" \
  --arg tag_key "$tag_key" \
  --arg tag_value "$tag_value" \
  '{
    stage: $stage,
    cluster: $cluster,
    required_tag: {key: $tag_key, value: $tag_value},
    tasks: .
  }' "$records_jsonl" > "$ARTIFACT_DIR/fis-targets-${stage}.json"

jq -s '.' "$empty_services_jsonl" > "$ARTIFACT_DIR/fis-targets-${stage}-empty-services.json"

violations="$(
  jq \
    --arg tag_key "$tag_key" \
    --arg tag_value "$tag_value" \
    '[.tasks[]
      | select(
          .lastStatus != "RUNNING"
          or ((any(.tags[]?; .key == $tag_key and .value == $tag_value)) | not)
          or ((any(.tags[]?; .key == "WorkerKind")) | not)
        )
      | {service, taskArn, lastStatus, desiredStatus, tags}]' \
    "$ARTIFACT_DIR/fis-targets-${stage}.json"
)"

empty_count="$(jq 'length' "$ARTIFACT_DIR/fis-targets-${stage}-empty-services.json")"
violation_count="$(printf '%s' "$violations" | jq 'length')"
if [[ "$empty_count" != "0" || "$violation_count" != "0" ]]; then
  printf '%s\n' "$violations" > "$ARTIFACT_DIR/fis-targets-${stage}-violations.json"
  echo "FIS ECS task targets are not resolvable; see $ARTIFACT_DIR/fis-targets-${stage}.json" >&2
  exit 1
fi

task_count="$(jq '.tasks | length' "$ARTIFACT_DIR/fis-targets-${stage}.json")"
echo "FIS ECS task targets resolvable for stage '$stage' with $task_count tagged worker tasks. Evidence: $ARTIFACT_DIR/fis-targets-${stage}.json"
