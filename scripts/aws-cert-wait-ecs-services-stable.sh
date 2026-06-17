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
    echo "$tool is required for aws-cert-wait-ecs-services-stable" >&2
    exit 1
  }
done

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"

outputs_path="$ARTIFACT_DIR/tofu-outputs.json"
if [[ ! -f "$outputs_path" ]]; then
  echo "$outputs_path is required for ECS service stability validation" >&2
  exit 1
fi

stage="${AWS_CERT_ECS_STABILITY_STAGE:-manual}"
cluster="$(jq -r '.ecs_cluster_name.value // empty' "$outputs_path")"
if [[ -z "$cluster" ]]; then
  echo "ecs_cluster_name output is required for ECS service stability validation" >&2
  exit 1
fi

./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-ecs-stability-${stage}.json" >/dev/null

services_json="$(aws ecs list-services --cluster "$cluster" --output json)"
printf '%s\n' "$services_json" > "$ARTIFACT_DIR/ecs-services-${stage}.json"
mapfile -t service_arns < <(printf '%s' "$services_json" | jq -r '.serviceArns[]')

if (( ${#service_arns[@]} == 0 )); then
  echo "No ECS services found for cluster $cluster" >&2
  exit 1
fi

aws ecs wait services-stable --cluster "$cluster" --services "${service_arns[@]}"

aws ecs describe-services \
  --cluster "$cluster" \
  --services "${service_arns[@]}" \
  --output json > "$ARTIFACT_DIR/ecs-services-stability-${stage}.json"

violations="$(
  jq '[.services[]
    | select(.desiredCount != .runningCount or .pendingCount != 0)
    | {serviceName, desiredCount, runningCount, pendingCount}]' \
    "$ARTIFACT_DIR/ecs-services-stability-${stage}.json"
)"

if [[ "$(printf '%s' "$violations" | jq 'length')" != "0" ]]; then
  printf '%s\n' "$violations" > "$ARTIFACT_DIR/ecs-services-stability-${stage}-violations.json"
  echo "ECS services are not stable; see $ARTIFACT_DIR/ecs-services-stability-${stage}-violations.json" >&2
  exit 1
fi

echo "ECS services stable for stage '$stage'. Evidence: $ARTIFACT_DIR/ecs-services-stability-${stage}.json"
