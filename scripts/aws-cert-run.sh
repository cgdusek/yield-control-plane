#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification commands" >&2
  exit 1
fi

command -v k6 >/dev/null 2>&1 || {
  echo "k6 is required for aws-cert-run" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required for aws-cert-run" >&2
  exit 1
}

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"

./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-run.json" >/dev/null
./scripts/aws-cert-admission-check.sh

outputs_path="$ARTIFACT_DIR/tofu-outputs.json"
if [[ -z "${API_BASE_URL:-}" && -f "$outputs_path" ]]; then
  export API_BASE_URL="$(jq -r '.api_base_url.value' "$outputs_path")"
fi
if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "API_BASE_URL is required or $outputs_path must exist" >&2
  exit 1
fi

export AWS_CERT_QUEUE_DRAIN_STAGE="pre-run"
./scripts/aws-cert-wait-queues-drained.sh
export AWS_CERT_ECS_STABILITY_STAGE="pre-run"
./scripts/aws-cert-wait-ecs-services-stable.sh

./scripts/smoke-create-sweep.sh
./scripts/smoke-failure-paths.sh

export AWS_CERT_QUEUE_DRAIN_STAGE="post-smoke"
./scripts/aws-cert-wait-queues-drained.sh

export CERT_RUN_ID="${CERT_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD)}"
printf '{"cert_run_id":"%s","api_base_url":"%s"}\n' "$CERT_RUN_ID" "$API_BASE_URL" \
  > "$ARTIFACT_DIR/cert-run-id.json"

k6 run \
  --summary-export "$ARTIFACT_DIR/k6-summary.json" \
  spec/certification/aws_certification_load.js

export AWS_CERT_QUEUE_DRAIN_STAGE="post-k6"
./scripts/aws-cert-wait-queues-drained.sh

fis_template_id="${FIS_EXPERIMENT_TEMPLATE_ID:-}"
if [[ -z "$fis_template_id" && -f "$outputs_path" ]]; then
  fis_template_id="$(jq -r '.fis_stop_worker_template_id.value // empty' "$outputs_path")"
fi
if [[ -n "$fis_template_id" ]]; then
  experiment_json="$(aws fis start-experiment \
    --experiment-template-id "$fis_template_id" \
    --output json)"
  printf '%s\n' "$experiment_json" > "$ARTIFACT_DIR/fis-start-experiment.json"
  experiment_id="$(printf '%s' "$experiment_json" | jq -r '.experiment.id')"
  fis_timeout_seconds="${AWS_CERT_FIS_TIMEOUT_SECONDS:-900}"
  fis_deadline=$((SECONDS + fis_timeout_seconds))
  while true; do
    aws fis get-experiment --id "$experiment_id" --output json > "$ARTIFACT_DIR/fis-experiment.json"
    fis_status="$(jq -r '.experiment.state.status' "$ARTIFACT_DIR/fis-experiment.json")"
    case "$fis_status" in
      completed | stopped)
        break
        ;;
      failed)
        echo "FIS experiment $experiment_id failed; see $ARTIFACT_DIR/fis-experiment.json" >&2
        exit 1
        ;;
    esac
    if [[ "$SECONDS" -ge "$fis_deadline" ]]; then
      echo "FIS experiment $experiment_id did not complete within ${fis_timeout_seconds}s" >&2
      exit 1
    fi
    sleep 15
  done
fi

export AWS_CERT_ECS_STABILITY_STAGE="post-fis"
./scripts/aws-cert-wait-ecs-services-stable.sh
export AWS_CERT_QUEUE_DRAIN_STAGE="post-fis"
./scripts/aws-cert-wait-queues-drained.sh

echo "AWS certification run complete. Evidence directory: $ARTIFACT_DIR"
