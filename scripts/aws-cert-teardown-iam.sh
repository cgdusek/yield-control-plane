#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification IAM teardown" >&2
  exit 1
fi

if [[ "${AWS_REGION:-}" != "us-west-2" && "${AWS_DEFAULT_REGION:-}" != "us-west-2" ]]; then
  echo "AWS_REGION or AWS_DEFAULT_REGION must be us-west-2" >&2
  exit 1
fi

for tool in aws jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required" >&2
    exit 1
  }
done

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
state_path="$ARTIFACT_DIR/bootstrap-state.json"

if [[ ! -f "$state_path" ]]; then
  echo "$state_path is required for bootstrap IAM teardown" >&2
  exit 1
fi

identity_json="$(aws sts get-caller-identity --output json)"
arn="$(printf '%s' "$identity_json" | jq -r '.Arn')"
if [[ "$arn" != arn:aws:iam::*:root ]]; then
  echo "bootstrap IAM teardown must run from sandbox root identity; current identity is $arn" >&2
  exit 1
fi

account_id="$(jq -r '.account_id' "$state_path")"
budget_name="$(jq -r '.budget' "$state_path")"
role_name="${AWS_CERT_RUNNER_ROLE_NAME:-$(jq -r '.runner_role_name // (.runner_role_arn | split("/")[-1])' "$state_path")}"
user_name="$(jq -r '.bootstrap_user_name // empty' "$state_path")"
access_key_id="$(jq -r '.bootstrap_user_access_key_id // empty' "$state_path")"

if [[ -n "$user_name" && "$user_name" != "null" ]]; then
  if [[ -n "$access_key_id" && "$access_key_id" != "null" ]]; then
    aws iam delete-access-key \
      --user-name "$user_name" \
      --access-key-id "$access_key_id" 2>/dev/null || true
  fi
  aws iam delete-user-policy \
    --user-name "$user_name" \
    --policy-name yield-control-plane-cert-bootstrap-assume-role 2>/dev/null || true
fi

if [[ "$(jq -r '.role_created_by_bootstrap' "$state_path")" == "true" ]]; then
  aws iam delete-role-policy \
    --role-name "$role_name" \
    --policy-name yield-control-plane-cert-runner 2>/dev/null || true
  aws iam delete-role --role-name "$role_name" 2>/dev/null || true
fi

if [[ -n "$user_name" && "$user_name" != "null" && "$(jq -r '.user_created_by_bootstrap // false' "$state_path")" == "true" ]]; then
  aws iam delete-user --user-name "$user_name" 2>/dev/null || true
fi

if [[ "$(jq -r '.budget_created_by_bootstrap' "$state_path")" == "true" ]]; then
  aws budgets delete-budget \
    --account-id "$account_id" \
    --budget-name "$budget_name" 2>/dev/null || true
fi

echo "AWS certification bootstrap IAM teardown complete."
