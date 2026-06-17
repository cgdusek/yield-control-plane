#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification commands" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || {
  echo "jq is required for aws-cert-admission-check" >&2
  exit 1
}

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"

duration="${CERT_DURATION:-30m}"
target_attempts="${CERT_TARGET_ATTEMPTS:-1000}"
vus="${CERT_VUS:-25}"
max_rate_per_minute="${AWS_CERT_MAX_ARRIVAL_RATE_PER_MINUTE:-60}"
max_target_attempts="${AWS_CERT_MAX_TARGET_ATTEMPTS:-2000}"
max_scheduled_iterations="${AWS_CERT_MAX_SCHEDULED_ITERATIONS:-2000}"

duration_seconds() {
  local value="$1"
  if [[ "$value" =~ ^([0-9]+)(s|m|h)$ ]]; then
    local amount="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "$unit" in
      s) printf '%s\n' "$amount" ;;
      m) printf '%s\n' $((amount * 60)) ;;
      h) printf '%s\n' $((amount * 60 * 60)) ;;
    esac
  else
    echo "CERT_DURATION must be an integer duration ending in s, m, or h" >&2
    exit 1
  fi
}

for value_name in target_attempts vus max_rate_per_minute max_target_attempts max_scheduled_iterations; do
  value="${!value_name}"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 1 )); then
    echo "$value_name must be a positive integer, got $value" >&2
    exit 1
  fi
done

seconds="$(duration_seconds "$duration")"
minutes=$(((seconds + 59) / 60))
if (( minutes < 1 )); then
  minutes=1
fi

if [[ -n "${CERT_RATE_PER_MINUTE:-}" ]]; then
  if ! [[ "$CERT_RATE_PER_MINUTE" =~ ^[0-9]+$ ]] || (( CERT_RATE_PER_MINUTE < 1 )); then
    echo "CERT_RATE_PER_MINUTE must be a positive integer" >&2
    exit 1
  fi
  rate_per_minute="$CERT_RATE_PER_MINUTE"
else
  rate_per_minute=$(((target_attempts + minutes - 1) / minutes))
  if (( rate_per_minute < 1 )); then
    rate_per_minute=1
  fi
fi

scheduled_iterations=$((rate_per_minute * minutes))
status="passed"
rejections=()
if (( target_attempts > max_target_attempts )); then
  status="failed"
  rejections+=("target_attempts_exceeds_cap")
fi
if (( rate_per_minute > max_rate_per_minute )); then
  status="failed"
  rejections+=("arrival_rate_exceeds_cap")
fi
if (( scheduled_iterations > max_scheduled_iterations )); then
  status="failed"
  rejections+=("scheduled_iterations_exceeds_cap")
fi

report_path="$ARTIFACT_DIR/admission-check.json"
if (( ${#rejections[@]} == 0 )); then
  rejections_json="[]"
else
  rejections_json="$(printf '%s\n' "${rejections[@]}" | jq -R . | jq -s .)"
fi
jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "$status" \
  --arg duration "$duration" \
  --argjson duration_seconds "$seconds" \
  --argjson duration_minutes "$minutes" \
  --argjson target_attempts "$target_attempts" \
  --argjson vus "$vus" \
  --argjson rate_per_minute "$rate_per_minute" \
  --argjson scheduled_iterations "$scheduled_iterations" \
  --argjson max_rate_per_minute "$max_rate_per_minute" \
  --argjson max_target_attempts "$max_target_attempts" \
  --argjson max_scheduled_iterations "$max_scheduled_iterations" \
  --argjson rejections "$rejections_json" \
  '{
    generated_at: $generated_at,
    status: $status,
    duration: $duration,
    duration_seconds: $duration_seconds,
    duration_minutes: $duration_minutes,
    target_attempts: $target_attempts,
    vus: $vus,
    rate_per_minute: $rate_per_minute,
    scheduled_iterations: $scheduled_iterations,
    caps: {
      max_rate_per_minute: $max_rate_per_minute,
      max_target_attempts: $max_target_attempts,
      max_scheduled_iterations: $max_scheduled_iterations
    },
    rejections: $rejections
  }' > "$report_path"

if [[ "$status" != "passed" ]]; then
  echo "AWS certification admission check failed. Evidence: $report_path" >&2
  exit 1
fi

echo "AWS certification admission check passed. Evidence: $report_path"
