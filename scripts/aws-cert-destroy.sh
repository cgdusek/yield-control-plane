#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification commands" >&2
  exit 1
fi

ARTIFACT_DIR="${AWS_CERT_ARTIFACT_DIR:-artifacts/aws-certification}"
mkdir -p "$ARTIFACT_DIR"
budget_limit_usd="${AWS_CERT_BUDGET_LIMIT_USD:-50}"

AWS_CERT_BUDGET_SPEND_MODE=cleanup ./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight-destroy.json" >/dev/null

TOFU_BIN="${TOFU_BIN:-tofu}"
if ! command -v "$TOFU_BIN" >/dev/null 2>&1; then
  if command -v opentofu >/dev/null 2>&1; then
    TOFU_BIN="opentofu"
  else
    echo "OpenTofu is required for aws-cert-destroy" >&2
    exit 1
  fi
fi

(
  cd infra/aws-simulation
  if "$TOFU_BIN" state show aws_budgets_budget.campaign >/dev/null 2>&1; then
    "$TOFU_BIN" state rm aws_budgets_budget.campaign >/dev/null
  fi
  "$TOFU_BIN" destroy -auto-approve \
    -var "teardown_ttl_hours=${AWS_CERT_TTL_HOURS}" \
    -var "budget_limit_usd=${budget_limit_usd}" \
    -var "budget_notification_email=${AWS_CERT_BUDGET_EMAIL:-}"
)

echo "AWS certification infrastructure destroyed."
