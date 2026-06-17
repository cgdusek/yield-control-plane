#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${AWS_CERTIFICATION_ENABLED:-}" != "1" ]]; then
  echo "AWS_CERTIFICATION_ENABLED=1 is required for AWS certification bootstrap" >&2
  exit 1
fi

if [[ "${AWS_REGION:-}" != "us-west-2" && "${AWS_DEFAULT_REGION:-}" != "us-west-2" ]]; then
  echo "AWS_REGION or AWS_DEFAULT_REGION must be us-west-2" >&2
  exit 1
fi

if [[ -z "${AWS_CERT_TTL_HOURS:-}" ]]; then
  echo "AWS_CERT_TTL_HOURS is required" >&2
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

identity_json="$(aws sts get-caller-identity --output json)"
account_id="$(printf '%s' "$identity_json" | jq -r '.Account')"
arn="$(printf '%s' "$identity_json" | jq -r '.Arn')"

if [[ "$arn" != arn:aws:iam::*:root ]]; then
  echo "bootstrap must run from the sandbox root identity; current identity is $arn" >&2
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
bootstrap_suffix="${AWS_CERT_BOOTSTRAP_SUFFIX:-$(date -u +%Y%m%d%H%M%S)}"
role_name="${AWS_CERT_RUNNER_ROLE_NAME:-yield-control-plane-cert-runner-${bootstrap_suffix}}"
user_name="${AWS_CERT_BOOTSTRAP_USER_NAME:-yield-control-plane-cert-bootstrap-${bootstrap_suffix}}"
session_name="${AWS_CERT_SESSION_NAME:-yield-control-plane-cert-$(date -u +%Y%m%d%H%M%S)}"
duration_seconds="${AWS_CERT_SESSION_SECONDS:-14400}"

budget_created=false
if aws budgets describe-budget \
  --account-id "$account_id" \
  --budget-name "$budget_name" \
  --output json > "$ARTIFACT_DIR/bootstrap-budget.json" 2>/dev/null
then
  limit="$(jq -r '.Budget.BudgetLimit.Amount' "$ARTIFACT_DIR/bootstrap-budget.json")"
  if ! awk "BEGIN { exit !($limit == $budget_limit_usd) }"; then
    echo "budget $budget_name must have a ${budget_limit_usd} USD limit, got $limit" >&2
    exit 1
  fi
else
  jq -n \
    --arg name "$budget_name" \
    --arg amount "$budget_limit_usd" \
    '{
      BudgetName: $name,
      BudgetLimit: {Amount: $amount, Unit: "USD"},
      TimeUnit: "MONTHLY",
      BudgetType: "COST"
    }' > "$ARTIFACT_DIR/bootstrap-budget-create.json"
  aws budgets create-budget \
    --account-id "$account_id" \
    --budget "file://$ARTIFACT_DIR/bootstrap-budget-create.json"
  budget_created=true
fi

fis_slr_role_name="AWSServiceRoleForFIS"
fis_slr_status="existing"
if aws iam get-role \
  --role-name "$fis_slr_role_name" \
  --output json > "$ARTIFACT_DIR/bootstrap-fis-service-linked-role.json" 2>/dev/null
then
  :
else
  aws iam create-service-linked-role \
    --aws-service-name fis.amazonaws.com \
    --description "Service-linked role for yield-control-plane AWS certification FIS experiments" \
    --output json > "$ARTIFACT_DIR/bootstrap-fis-service-linked-role-create.json"
  fis_slr_status="created"
  sleep "${AWS_CERT_IAM_PROPAGATION_SECONDS:-10}"
  aws iam get-role \
    --role-name "$fis_slr_role_name" \
    --output json > "$ARTIFACT_DIR/bootstrap-fis-service-linked-role.json"
fi

trust_path="$ARTIFACT_DIR/bootstrap-role-trust.json"
policy_path="$ARTIFACT_DIR/bootstrap-role-policy.json"
user_policy_path="$ARTIFACT_DIR/bootstrap-user-policy.json"
role_arn="arn:aws:iam::${account_id}:role/${role_name}"
user_arn="arn:aws:iam::${account_id}:user/${user_name}"

jq -n \
  --arg account_id "$account_id" \
  '{
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: {AWS: ("arn:aws:iam::" + $account_id + ":root")},
      Action: "sts:AssumeRole"
    }]
  }' > "$trust_path"

jq -n \
  --arg account_id "$account_id" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "RegionalCertificationServices",
        Effect: "Allow",
        Action: [
          "ec2:*",
          "elasticloadbalancing:*",
          "ecs:*",
          "ecr:*",
          "rds:*",
          "sns:*",
          "sqs:*",
          "kms:*",
          "secretsmanager:*",
          "logs:*",
          "cloudwatch:*",
          "servicediscovery:*",
          "fis:*",
          "tag:*"
        ],
        Resource: "*",
        Condition: {
          StringEquals: {"aws:RequestedRegion": "us-west-2"}
        }
      },
      {
        Sid: "CertificationIamRoles",
        Effect: "Allow",
        Action: [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:PassRole"
        ],
        Resource: ("arn:aws:iam::" + $account_id + ":role/yield-control-plane-cert*")
      },
      {
        Sid: "AwsServiceLinkedRoles",
        Effect: "Allow",
        Action: [
          "iam:CreateServiceLinkedRole",
          "iam:DeleteServiceLinkedRole",
          "iam:GetServiceLinkedRoleDeletionStatus"
        ],
        Resource: "*",
        Condition: {
          StringEquals: {
            "iam:AWSServiceName": [
              "ecs.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "rds.amazonaws.com",
              "servicediscovery.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid: "EcsServiceLinkedRoleTagging",
        Effect: "Allow",
        Action: [
          "iam:GetRole",
          "iam:DeleteServiceLinkedRole",
          "iam:TagRole",
          "iam:UntagRole"
        ],
        Resource: ("arn:aws:iam::" + $account_id + ":role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS*")
      },
      {
        Sid: "FisServiceLinkedRoleRead",
        Effect: "Allow",
        Action: "iam:GetRole",
        Resource: ("arn:aws:iam::" + $account_id + ":role/aws-service-role/fis.amazonaws.com/AWSServiceRoleForFIS")
      },
      {
        Sid: "ServiceLinkedRoleDeletionStatus",
        Effect: "Allow",
        Action: "iam:GetServiceLinkedRoleDeletionStatus",
        Resource: "*"
      },
      {
        Sid: "PrivateDnsNamespaceSupport",
        Effect: "Allow",
        Action: [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets",
          "route53:ChangeTagsForResource",
          "route53:ListTagsForResource"
        ],
        Resource: "*"
      },
      {
        Sid: "BudgetAndCostEvidence",
        Effect: "Allow",
        Action: [
          "budgets:CreateBudget",
          "budgets:DescribeBudget",
          "budgets:DeleteBudget",
          "budgets:ModifyBudget",
          "budgets:ListTagsForResource",
          "budgets:TagResource",
          "budgets:UntagResource",
          "budgets:ViewBudget",
          "ce:GetCostAndUsage"
        ],
        Resource: "*"
      },
      {
        Sid: "IdentityEvidence",
        Effect: "Allow",
        Action: "sts:GetCallerIdentity",
        Resource: "*"
      }
    ]
  }' > "$policy_path"

jq -n \
  --arg role_arn "$role_arn" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "AssumeCertificationRoleOnly",
        Effect: "Allow",
        Action: "sts:AssumeRole",
        Resource: $role_arn
      },
      {
        Sid: "IdentityEvidence",
        Effect: "Allow",
        Action: "sts:GetCallerIdentity",
        Resource: "*"
      }
    ]
  }' > "$user_policy_path"

user_created=false
if aws iam get-user --user-name "$user_name" --output json > "$ARTIFACT_DIR/bootstrap-user.json" 2>/dev/null; then
  :
else
  aws iam create-user \
    --user-name "$user_name" \
    --tags \
      Key=Project,Value=yield-control-plane \
      Key=CertificationWorkstream,Value=aws-simulation \
      Key=TeardownTtlHours,Value="$AWS_CERT_TTL_HOURS" \
    > "$ARTIFACT_DIR/bootstrap-user.json"
  user_created=true
fi

aws iam put-user-policy \
  --user-name "$user_name" \
  --policy-name yield-control-plane-cert-bootstrap-assume-role \
  --policy-document "file://$user_policy_path"

for existing_access_key_id in $(aws iam list-access-keys \
  --user-name "$user_name" \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text 2>/dev/null || true); do
  [[ -n "$existing_access_key_id" && "$existing_access_key_id" != "None" ]] || continue
  aws iam delete-access-key \
    --user-name "$user_name" \
    --access-key-id "$existing_access_key_id" 2>/dev/null || true
done

access_key_json="$(aws iam create-access-key --user-name "$user_name" --output json)"
printf '%s\n' "$access_key_json" > "$ARTIFACT_DIR/bootstrap-user-access-key.json"
bootstrap_access_key_id="$(printf '%s' "$access_key_json" | jq -r '.AccessKey.AccessKeyId')"
bootstrap_secret_access_key="$(printf '%s' "$access_key_json" | jq -r '.AccessKey.SecretAccessKey')"

role_created=false
if aws iam get-role --role-name "$role_name" --output json > "$ARTIFACT_DIR/bootstrap-role.json" 2>/dev/null; then
  aws iam update-assume-role-policy \
    --role-name "$role_name" \
    --policy-document "file://$trust_path"
else
  aws iam create-role \
    --role-name "$role_name" \
    --assume-role-policy-document "file://$trust_path" \
    --max-session-duration 14400 \
    --tags \
      Key=Project,Value=yield-control-plane \
      Key=CertificationWorkstream,Value=aws-simulation \
      Key=TeardownTtlHours,Value="$AWS_CERT_TTL_HOURS" \
    > "$ARTIFACT_DIR/bootstrap-role.json"
  role_created=true
fi

aws iam put-role-policy \
  --role-name "$role_name" \
  --policy-name yield-control-plane-cert-runner \
  --policy-document "file://$policy_path"

# IAM user, policy, and role propagation are eventually consistent.
sleep "${AWS_CERT_IAM_PROPAGATION_SECONDS:-10}"

assume_json="$(env -u AWS_PROFILE \
  AWS_ACCESS_KEY_ID="$bootstrap_access_key_id" \
  AWS_SECRET_ACCESS_KEY="$bootstrap_secret_access_key" \
  AWS_REGION=us-west-2 \
  AWS_DEFAULT_REGION=us-west-2 \
  aws sts assume-role \
  --role-arn "$role_arn" \
  --role-session-name "$session_name" \
  --duration-seconds "$duration_seconds" \
  --output json)"

printf '%s\n' "$assume_json" > "$ARTIFACT_DIR/bootstrap-assume-role.json"

env_path="$ARTIFACT_DIR/aws-cert-temp-role.env"
umask 077
{
  printf 'export AWS_ACCESS_KEY_ID=%q\n' "$(printf '%s' "$assume_json" | jq -r '.Credentials.AccessKeyId')"
  printf 'export AWS_SECRET_ACCESS_KEY=%q\n' "$(printf '%s' "$assume_json" | jq -r '.Credentials.SecretAccessKey')"
  printf 'export AWS_SESSION_TOKEN=%q\n' "$(printf '%s' "$assume_json" | jq -r '.Credentials.SessionToken')"
  printf 'export AWS_REGION=us-west-2\n'
  printf 'export AWS_DEFAULT_REGION=us-west-2\n'
  printf 'export AWS_CERTIFICATION_ENABLED=1\n'
  printf 'export AWS_CERT_TTL_HOURS=%q\n' "$AWS_CERT_TTL_HOURS"
  printf 'export AWS_CERT_ACCOUNT_ID=%q\n' "$account_id"
  printf 'export AWS_CERT_BUDGET_NAME=%q\n' "$budget_name"
  printf 'export AWS_CERT_BUDGET_LIMIT_USD=%q\n' "$budget_limit_usd"
  printf 'export AWS_CERT_RUNNER_ROLE_NAME=%q\n' "$role_name"
  printf 'unset AWS_PROFILE\n'
} > "$env_path"

jq -n \
  --arg account_id "$account_id" \
  --arg root_arn "$arn" \
  --arg role_arn "$role_arn" \
  --arg role_name "$role_name" \
  --arg user_arn "$user_arn" \
  --arg user_name "$user_name" \
  --arg access_key_id "$bootstrap_access_key_id" \
  --arg budget "$budget_name" \
  --arg fis_slr_role_name "$fis_slr_role_name" \
  --arg fis_slr_status "$fis_slr_status" \
  --argjson budget_limit_usd "$budget_limit_usd" \
  --argjson budget_created "$budget_created" \
  --argjson role_created "$role_created" \
  --argjson user_created "$user_created" \
  --arg env_path "$env_path" \
  '{
    account_id: $account_id,
    root_arn: $root_arn,
    runner_role_arn: $role_arn,
    runner_role_name: $role_name,
    bootstrap_user_arn: $user_arn,
    bootstrap_user_name: $user_name,
    bootstrap_user_access_key_id: $access_key_id,
    budget: $budget,
    budget_limit_usd: $budget_limit_usd,
    fis_service_linked_role_name: $fis_slr_role_name,
    fis_service_linked_role_status: $fis_slr_status,
    budget_created_by_bootstrap: $budget_created,
    role_created_by_bootstrap: $role_created,
    user_created_by_bootstrap: $user_created,
    temporary_env_file: $env_path
  }' > "$ARTIFACT_DIR/bootstrap-state.json"

echo "AWS certification bootstrap complete. Source $env_path to use temporary scoped credentials."
