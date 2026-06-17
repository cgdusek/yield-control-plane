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

./scripts/aws-cert-preflight.sh | tee "$ARTIFACT_DIR/preflight.json" >/dev/null
./scripts/validate-aws-certification.sh >/dev/null

TOFU_BIN="${TOFU_BIN:-tofu}"
if ! command -v "$TOFU_BIN" >/dev/null 2>&1; then
  if command -v opentofu >/dev/null 2>&1; then
    TOFU_BIN="opentofu"
  else
    echo "OpenTofu is required for aws-cert-deploy" >&2
    exit 1
  fi
fi

git_sha="$(git rev-parse --short HEAD)"
image_tag="${AWS_CERT_IMAGE_TAG:-$git_sha}"
aws_account_id="$(jq -r '.account_id' "$ARTIFACT_DIR/preflight.json")"
budget_name="$(jq -r '.budget' "$ARTIFACT_DIR/preflight.json")"
ecr_host="${aws_account_id}.dkr.ecr.us-west-2.amazonaws.com"

(
  cd infra/aws-simulation
  "$TOFU_BIN" init
  if ! "$TOFU_BIN" state show aws_budgets_budget.campaign >/dev/null 2>&1; then
    "$TOFU_BIN" import \
      -var "teardown_ttl_hours=${AWS_CERT_TTL_HOURS}" \
      -var "budget_limit_usd=${budget_limit_usd}" \
      -var "budget_notification_email=${AWS_CERT_BUDGET_EMAIL:-}" \
      aws_budgets_budget.campaign "${aws_account_id}:${budget_name}" ||
      "$TOFU_BIN" import \
        -var "teardown_ttl_hours=${AWS_CERT_TTL_HOURS}" \
        -var "budget_limit_usd=${budget_limit_usd}" \
        -var "budget_notification_email=${AWS_CERT_BUDGET_EMAIL:-}" \
        aws_budgets_budget.campaign "$budget_name"
  fi
  "$TOFU_BIN" apply -auto-approve \
    -target=aws_ecr_repository.api \
    -target=aws_ecr_repository.worker \
    -target=aws_ecr_repository.mock_transfer_agent \
    -target=aws_ecr_repository.certifier \
    -var "teardown_ttl_hours=${AWS_CERT_TTL_HOURS}" \
    -var "budget_limit_usd=${budget_limit_usd}" \
    -var "budget_notification_email=${AWS_CERT_BUDGET_EMAIL:-}"
  "$TOFU_BIN" output -json ecr_repository_urls > "../../$ARTIFACT_DIR/ecr-repositories.json"
)

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin "$ecr_host"

api_repo="$(jq -r '.api' "$ARTIFACT_DIR/ecr-repositories.json")"
worker_repo="$(jq -r '.worker' "$ARTIFACT_DIR/ecr-repositories.json")"
mock_repo="$(jq -r '.mock_transfer_agent' "$ARTIFACT_DIR/ecr-repositories.json")"
certifier_repo="$(jq -r '.certifier' "$ARTIFACT_DIR/ecr-repositories.json")"
image_platform="${AWS_CERT_IMAGE_PLATFORM:-linux/arm64}"

if [[ "${AWS_CERT_SKIP_IMAGE_BUILD:-0}" == "1" ]]; then
  for repo_url in "$api_repo" "$worker_repo" "$mock_repo" "$certifier_repo"; do
    repo_name="${repo_url#${ecr_host}/}"
    aws ecr describe-images \
      --region us-west-2 \
      --repository-name "$repo_name" \
      --image-ids "imageTag=${image_tag}" >/dev/null
  done
else
  docker build --platform "$image_platform" -t "${api_repo}:${image_tag}" -f services/api/Dockerfile .
  docker build --platform "$image_platform" -t "${worker_repo}:${image_tag}" -f services/worker/Dockerfile .
  docker build --platform "$image_platform" -t "${mock_repo}:${image_tag}" -f services/mock-transfer-agent/Dockerfile .
  docker build --platform "$image_platform" -t "${certifier_repo}:${image_tag}" -f services/certifier/Dockerfile .

  docker push "${api_repo}:${image_tag}"
  docker push "${worker_repo}:${image_tag}"
  docker push "${mock_repo}:${image_tag}"
  docker push "${certifier_repo}:${image_tag}"
fi

(
  cd infra/aws-simulation
  "$TOFU_BIN" apply -auto-approve \
    -var "api_image_uri=${api_repo}:${image_tag}" \
    -var "worker_image_uri=${worker_repo}:${image_tag}" \
    -var "mock_transfer_agent_image_uri=${mock_repo}:${image_tag}" \
    -var "certifier_image_uri=${certifier_repo}:${image_tag}" \
    -var "runtime_cpu_architecture=${AWS_CERT_RUNTIME_CPU_ARCHITECTURE:-ARM64}" \
    -var "teardown_ttl_hours=${AWS_CERT_TTL_HOURS}" \
    -var "budget_limit_usd=${budget_limit_usd}" \
    -var "budget_notification_email=${AWS_CERT_BUDGET_EMAIL:-}"
  "$TOFU_BIN" output -json > "../../$ARTIFACT_DIR/tofu-outputs.json"
)

echo "AWS certification deployment complete. Outputs: $ARTIFACT_DIR/tofu-outputs.json"
