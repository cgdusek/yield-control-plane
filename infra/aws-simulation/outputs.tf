output "api_base_url" {
  description = "HTTP base URL for the certification API."
  value       = "http://${aws_lb.api.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "sns_topic_arn" {
  description = "Domain events SNS topic ARN."
  value       = aws_sns_topic.domain_events.arn
}

output "worker_queue_urls" {
  description = "Worker SQS queue URLs."
  value       = { for name, queue in aws_sqs_queue.worker : name => queue.id }
}

output "worker_dlq_urls" {
  description = "Worker SQS DLQ URLs."
  value       = { for name, queue in aws_sqs_queue.dlq : name => queue.id }
}

output "fis_stop_worker_template_id" {
  description = "AWS FIS template id for stopping one worker task."
  value       = aws_fis_experiment_template.stop_worker_task.id
}

output "ecr_repository_urls" {
  description = "ECR repositories used by aws-cert-deploy.sh."
  value = {
    api                 = aws_ecr_repository.api.repository_url
    worker              = aws_ecr_repository.worker.repository_url
    mock_transfer_agent = aws_ecr_repository.mock_transfer_agent.repository_url
    certifier           = aws_ecr_repository.certifier.repository_url
  }
}

output "certifier_task_definition_arn" {
  description = "Certifier one-off ECS task definition ARN."
  value       = aws_ecs_task_definition.certifier.arn
}

output "certifier_log_group_name" {
  description = "CloudWatch log group for the certifier one-off ECS task."
  value       = aws_cloudwatch_log_group.service["certifier"].name
}

output "public_subnet_ids" {
  description = "Public subnet ids for one-off ECS certifier runs."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "ecs_security_group_id" {
  description = "Security group id for ECS tasks."
  value       = aws_security_group.ecs.id
}
