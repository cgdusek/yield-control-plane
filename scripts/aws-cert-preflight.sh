#!/usr/bin/env bash
set -euo pipefail

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification commands" >&2
  exit 1
fi

if [[ "${AWS_REGION:-}" != "us-west-2" && "${AWS_DEFAULT_REGION:-}" != "us-west-2" ]]; then
  echo "AWS_REGION or AWS_DEFAULT_REGION must be us-west-2" >&2
  exit 1
fi

if [[ -z "${AWS_CERT_TTL_HOURS:-}" ]]; then
  echo "AWS_CERT_TTL_HOURS is required so resources carry a teardown TTL" >&2
  exit 1
fi

if ! [[ "$AWS_CERT_TTL_HOURS" =~ ^[0-9]+$ ]] || (( AWS_CERT_TTL_HOURS < 1 || AWS_CERT_TTL_HOURS > 24 )); then
  echo "AWS_CERT_TTL_HOURS must be an integer from 1 through 24" >&2
  exit 1
fi

for tool in aws jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required" >&2
    exit 1
  }
done

identity_json="$(aws sts get-caller-identity --output json)"
account_id="$(printf '%s' "$identity_json" | jq -r '.Account')"
arn="$(printf '%s' "$identity_json" | jq -r '.Arn')"

if [[ "$arn" == arn:aws:iam::*:root ]]; then
  echo "AWS root identity is not permitted for deploy/test loops: $arn" >&2
  exit 1
fi

if [[ -n "${AWS_CERT_ACCOUNT_ID:-}" && "$account_id" != "$AWS_CERT_ACCOUNT_ID" ]]; then
  echo "caller account $account_id does not match AWS_CERT_ACCOUNT_ID=$AWS_CERT_ACCOUNT_ID" >&2
  exit 1
fi

budget_limit_usd="${AWS_CERT_BUDGET_LIMIT_USD:-50}"
if ! [[ "$budget_limit_usd" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "AWS_CERT_BUDGET_LIMIT_USD must be a positive numeric USD amount" >&2
  exit 1
fi
if awk "BEGIN { exit !($budget_limit_usd <= 0) }"; then
  echo "AWS_CERT_BUDGET_LIMIT_USD must be greater than zero" >&2
  exit 1
fi

budget_name="${AWS_CERT_BUDGET_NAME:-yield-control-plane-cert-${budget_limit_usd}-usd}"
if ! aws budgets describe-budget \
  --account-id "$account_id" \
  --budget-name "$budget_name" \
  --output json >/tmp/ycp-aws-cert-budget.json
then
  echo "required budget guardrail is missing: $budget_name" >&2
  exit 1
fi

limit="$(jq -r '.Budget.BudgetLimit.Amount' /tmp/ycp-aws-cert-budget.json)"
if ! awk "BEGIN { exit !($limit == $budget_limit_usd) }"; then
  echo "budget $budget_name must have a ${budget_limit_usd} USD limit, got $limit" >&2
  exit 1
fi

actual_spend="$(jq -r '.Budget.CalculatedSpend.ActualSpend.Amount // "0"' /tmp/ycp-aws-cert-budget.json)"
forecasted_spend="$(jq -r '.Budget.CalculatedSpend.ForecastedSpend.Amount // "0"' /tmp/ycp-aws-cert-budget.json)"
budget_spend_mode="${AWS_CERT_BUDGET_SPEND_MODE:-enforce}"
if [[ "$budget_spend_mode" != "cleanup" ]] &&
  awk "BEGIN { exit !($actual_spend > $limit) }"
then
  echo "budget $budget_name actual spend $actual_spend USD exceeds limit $limit USD; stopping fail-closed" >&2
  exit 1
fi

fis_slr_role_name="AWSServiceRoleForFIS"
if ! aws iam get-role \
  --role-name "$fis_slr_role_name" \
  --output json >/tmp/ycp-aws-cert-fis-service-linked-role.json
then
  echo "required FIS service-linked role is missing: $fis_slr_role_name; rerun root bootstrap before certification run" >&2
  exit 1
fi
fis_slr_arn="$(jq -r '.Role.Arn' /tmp/ycp-aws-cert-fis-service-linked-role.json)"

jq -n \
  --arg account_id "$account_id" \
  --arg arn "$arn" \
  --arg region "${AWS_REGION:-${AWS_DEFAULT_REGION:-}}" \
  --arg budget "$budget_name" \
  --arg ttl_hours "$AWS_CERT_TTL_HOURS" \
  --arg budget_spend_mode "$budget_spend_mode" \
  --arg fis_service_linked_role_arn "$fis_slr_arn" \
  --argjson budget_limit "$limit" \
  --argjson budget_actual_spend "$actual_spend" \
  --argjson budget_forecasted_spend "$forecasted_spend" \
  '{
    account_id: $account_id,
    arn: $arn,
    region: $region,
    budget: $budget,
    budget_limit_usd: $budget_limit,
    budget_actual_spend_usd: $budget_actual_spend,
    budget_forecasted_spend_usd: $budget_forecasted_spend,
    budget_spend_mode: $budget_spend_mode,
    fis_service_linked_role_arn: $fis_service_linked_role_arn,
    teardown_ttl_hours: ($ttl_hours | tonumber),
    root_identity: false,
    opt_in: true
  }'
