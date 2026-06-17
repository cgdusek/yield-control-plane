variable "aws_region" {
  description = "AWS region for the sandbox certification campaign."
  type        = string
  default     = "us-west-2"
}

variable "workload_name" {
  description = "Stable workload prefix."
  type        = string
  default     = "yield-control-plane-cert"
}

variable "environment" {
  description = "Environment label."
  type        = string
  default     = "cert"
}

variable "budget_limit_usd" {
  description = "Maximum intended campaign budget in USD."
  type        = number
  default     = 50
}

variable "budget_notification_email" {
  description = "Email for budget alerts. Leave empty to create the budget without email notification blocks."
  type        = string
  default     = ""
}

variable "teardown_ttl_hours" {
  description = "Required teardown TTL tag value in hours."
  type        = number
  default     = 24
}

variable "api_image_uri" {
  description = "Pushed API image URI."
  type        = string
  default     = ""
}

variable "worker_image_uri" {
  description = "Pushed worker image URI."
  type        = string
  default     = ""
}

variable "mock_transfer_agent_image_uri" {
  description = "Pushed mock transfer-agent image URI."
  type        = string
  default     = ""
}

variable "certifier_image_uri" {
  description = "Pushed certifier image URI."
  type        = string
  default     = ""
}

variable "api_desired_count" {
  description = "API desired task count."
  type        = number
  default     = 1
}

variable "worker_desired_count" {
  description = "Worker desired task count per worker service."
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "RDS instance class for the cost-bounded sandbox campaign."
  type        = string
  default     = "db.t4g.micro"
}

variable "runtime_cpu_architecture" {
  description = "ECS task CPU architecture for Fargate tasks."
  type        = string
  default     = "ARM64"
}
