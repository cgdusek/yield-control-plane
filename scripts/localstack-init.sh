#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
REGION="${AWS_REGION:-us-east-1}"
TOPIC_NAME="${SNS_TOPIC_NAME:-domain-events}"
QUEUES=(
  "${SQS_TRANSFER_AGENT_QUEUE:-transfer-agent-worker-queue}"
  "${SQS_RECONCILIATION_QUEUE:-reconciliation-worker-queue}"
  "${SQS_NOTIFICATION_QUEUE:-notification-worker-queue}"
  "${SQS_CHAIN_WATCHER_QUEUE:-chain-watcher-queue}"
)

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="$REGION"

aws_local() {
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

topic_arn="$(aws_local sns create-topic --name "$TOPIC_NAME" --query TopicArn --output text)"
echo "SNS topic: $topic_arn"

for queue in "${QUEUES[@]}"; do
  dlq="${queue}-dlq"
  dlq_url="$(aws_local sqs create-queue --queue-name "$dlq" --query QueueUrl --output text)"
  dlq_arn="$(aws_local sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)"
  redrive_policy="$(jq -cn --arg arn "$dlq_arn" '{deadLetterTargetArn:$arn,maxReceiveCount:"5"}')"
  queue_attributes="$(jq -cn --arg rp "$redrive_policy" '{VisibilityTimeout:"30",ReceiveMessageWaitTimeSeconds:"10",RedrivePolicy:$rp}')"
  queue_url="$(aws_local sqs create-queue --queue-name "$queue" --attributes "$queue_attributes" --query QueueUrl --output text)"
  queue_arn="$(aws_local sqs get-queue-attributes --queue-url "$queue_url" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)"
  aws_local sns subscribe --topic-arn "$topic_arn" --protocol sqs --notification-endpoint "$queue_arn" --attributes RawMessageDelivery=true >/dev/null
  policy="$(jq -cn --arg qarn "$queue_arn" --arg tarn "$topic_arn" '{Version:"2012-10-17",Statement:[{Effect:"Allow",Principal:"*",Action:"sqs:SendMessage",Resource:$qarn,Condition:{ArnEquals:{"aws:SourceArn":$tarn}}}]}')"
  policy_attributes="$(jq -cn --arg policy "$policy" '{Policy:$policy}')"
  aws_local sqs set-queue-attributes --queue-url "$queue_url" --attributes "$policy_attributes" >/dev/null
  echo "SQS queue: $queue_url"
done

echo "LocalStack SNS/SQS initialized."
