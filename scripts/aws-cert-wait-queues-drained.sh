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
    echo "$tool is required for aws-cert-wait-queues-drained" >&2
    exit 1
  }
done

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"

outputs_path="$ARTIFACT_DIR/tofu-outputs.json"
if [[ ! -f "$outputs_path" ]]; then
  echo "$outputs_path is required for queue drain validation" >&2
  exit 1
fi

stage="${AWS_CERT_QUEUE_DRAIN_STAGE:-manual}"
timeout_seconds="${AWS_CERT_QUEUE_DRAIN_TIMEOUT_SECONDS:-900}"
interval_seconds="${AWS_CERT_QUEUE_DRAIN_INTERVAL_SECONDS:-15}"
report_path="$ARTIFACT_DIR/queue-drain-${stage}.json"

./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-queue-drain-${stage}.json" >/dev/null

tmp_queues="$(mktemp)"
trap 'rm -f "$tmp_queues"' EXIT

deadline=$((SECONDS + timeout_seconds))

while true; do
  : > "$tmp_queues"
  total_messages=0
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  while IFS=$'\t' read -r queue_kind queue_name queue_url; do
    [[ -n "$queue_url" ]] || continue
    attrs_json="$(aws sqs get-queue-attributes \
      --queue-url "$queue_url" \
      --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
      --output json)"
    visible="$(printf '%s' "$attrs_json" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"')"
    not_visible="$(printf '%s' "$attrs_json" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // "0"')"
    delayed="$(printf '%s' "$attrs_json" | jq -r '.Attributes.ApproximateNumberOfMessagesDelayed // "0"')"
    queue_total=$((visible + not_visible + delayed))
    total_messages=$((total_messages + queue_total))

    jq -n \
      --arg kind "$queue_kind" \
      --arg name "$queue_name" \
      --arg url "$queue_url" \
      --argjson visible "$visible" \
      --argjson not_visible "$not_visible" \
      --argjson delayed "$delayed" \
      --argjson total "$queue_total" \
      '{
        kind: $kind,
        name: $name,
        queue_url: $url,
        visible: $visible,
        not_visible: $not_visible,
        delayed: $delayed,
        total_messages: $total
      }' >> "$tmp_queues"
  done < <(
    jq -r '
      (.worker_queue_urls.value | to_entries[] | ["source", .key, .value]),
      (.worker_dlq_urls.value | to_entries[] | ["dlq", .key, .value])
      | @tsv
    ' "$outputs_path"
  )

  if [[ "$total_messages" -eq 0 ]]; then
    status="passed"
  else
    status="waiting"
  fi

  jq -s \
    --arg generated_at "$generated_at" \
    --arg stage "$stage" \
    --arg status "$status" \
    --argjson timeout_seconds "$timeout_seconds" \
    --argjson interval_seconds "$interval_seconds" \
    --argjson total_messages "$total_messages" \
    '{
      generated_at: $generated_at,
      stage: $stage,
      status: $status,
      timeout_seconds: $timeout_seconds,
      interval_seconds: $interval_seconds,
      total_messages: $total_messages,
      queues: .
    }' "$tmp_queues" > "$report_path"

  if [[ "$total_messages" -eq 0 ]]; then
    echo "SQS queues drained for stage '$stage'. Evidence: $report_path"
    exit 0
  fi

  if [[ "$SECONDS" -ge "$deadline" ]]; then
    jq \
      --arg status "failed" \
      '.status = $status' "$report_path" > "${report_path}.tmp"
    mv "${report_path}.tmp" "$report_path"
    echo "SQS queues did not drain for stage '$stage' within ${timeout_seconds}s. Evidence: $report_path" >&2
    exit 1
  fi

  sleep "$interval_seconds"
done
