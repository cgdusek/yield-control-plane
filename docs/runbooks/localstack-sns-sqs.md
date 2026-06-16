# LocalStack SNS/SQS

## Validate LocalStack

```bash
curl -fsS http://localhost:4566/_localstack/health
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 ./scripts/localstack-init.sh
```

## Inspect Resources

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url http://localhost:4566 sns list-topics
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url http://localhost:4566 sqs list-queues
```

## Rebuild Resources

```bash
make dev-reset
make dev-up
```

This recreates Postgres and LocalStack volumes and reruns queue/topic initialization.

