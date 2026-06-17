data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  image_tag = "cert"
  common_tags = {
    Project                 = "yield-control-plane"
    Environment             = var.environment
    ManagedBy               = "opentofu"
    CertificationWorkstream = "aws-simulation"
    CostBoundaryUsd         = tostring(var.budget_limit_usd)
    TeardownTtlHours        = tostring(var.teardown_ttl_hours)
  }
  azs = {
    a = data.aws_availability_zones.available.names[0]
    b = data.aws_availability_zones.available.names[1]
  }
  worker_queues = toset(["transfer-agent", "reconciliation", "chain-watcher", "notification"])
}

resource "aws_kms_key" "certification" {
  description             = "KMS key for yield-control-plane certification simulation"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.workload_name}/*"
          }
        }
      },
      {
        Sid    = "AllowSnsToSendToEncryptedSqs"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.workload_name}-domain-events"
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "certification" {
  name          = "alias/${var.workload_name}"
  target_key_id = aws_kms_key.certification.key_id
}

resource "aws_vpc" "main" {
  cidr_block           = "10.80.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, index(keys(local.azs), each.key))
  availability_zone       = each.value
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  for_each          = local.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 20 + index(keys(local.azs), each.key))
  availability_zone = each.value
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each       = local.azs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${var.workload_name}-alb"
  description = "ALB ingress for certification simulation"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP test ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.workload_name}-ecs"
  description = "ECS task security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "ALB to API"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service-to-service mock transfer agent"
    from_port   = 8090
    to_port     = 8090
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.workload_name}-rds"
  description = "RDS ingress from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "${var.workload_name}/api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "worker" {
  name                 = "${var.workload_name}/worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "mock_transfer_agent" {
  name                 = "${var.workload_name}/mock-transfer-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "certifier" {
  name                 = "${var.workload_name}/certifier"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_sns_topic" "domain_events" {
  name              = "${var.workload_name}-domain-events"
  kms_master_key_id = aws_kms_key.certification.arn
}

resource "aws_sqs_queue" "dlq" {
  for_each                  = local.worker_queues
  name                      = "${var.workload_name}-${each.value}-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.certification.arn
}

resource "aws_sqs_queue" "worker" {
  for_each                   = local.worker_queues
  name                       = "${var.workload_name}-${each.key}-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 5
  kms_master_key_id          = aws_kms_key.certification.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 5
  })
}

resource "aws_sns_topic_subscription" "worker" {
  for_each             = local.worker_queues
  topic_arn            = aws_sns_topic.domain_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.worker[each.key].arn
  raw_message_delivery = true
}

resource "aws_sqs_queue_policy" "worker" {
  for_each  = local.worker_queues
  queue_url = aws_sqs_queue.worker[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sns.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.worker[each.key].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.domain_events.arn
        }
      }
    }]
  })
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = var.workload_name
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}

resource "aws_db_instance" "postgres" {
  identifier                   = var.workload_name
  engine                       = "postgres"
  engine_version               = "17"
  instance_class               = var.db_instance_class
  allocated_storage            = 20
  storage_encrypted            = true
  kms_key_id                   = aws_kms_key.certification.arn
  db_name                      = "yield_control"
  username                     = "yield"
  password                     = random_password.db.result
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  backup_retention_period      = 1
  deletion_protection          = false
  skip_final_snapshot          = true
  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
}

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.workload_name}/database-url"
  kms_key_id              = aws_kms_key.certification.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = format(
    "postgres://yield:%s@%s:5432/yield_control",
    random_password.db.result,
    aws_db_instance.postgres.address
  )
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.workload_name}.local"
  description = "Private DNS namespace for certification simulation"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "mock_transfer_agent" {
  name = "mock-transfer-agent"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = toset(["api", "worker", "mock-transfer-agent", "certifier"])
  name              = "/ecs/${var.workload_name}/${each.value}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.certification.arn
}

resource "aws_iam_role" "task_execution" {
  name = "${var.workload_name}-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${var.workload_name}-task-execution-secrets"
  role = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Resource = [
        aws_secretsmanager_secret.database_url.arn,
        aws_kms_key.certification.arn
      ]
    }]
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.workload_name}-task"
  assume_role_policy = aws_iam_role.task_execution.assume_role_policy
}

resource "aws_iam_role_policy" "task_messaging" {
  name = "${var.workload_name}-task-messaging"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.domain_events.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = concat(
          [for queue in aws_sqs_queue.worker : queue.arn],
          [for queue in aws_sqs_queue.dlq : queue.arn]
        )
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.certification.arn
      }
    ]
  })
}

resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
  description      = "Service-linked role for ECS capacity provider operations in the certification sandbox"
}

resource "aws_ecs_cluster" "main" {
  name = var.workload_name
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  depends_on         = [aws_iam_service_linked_role.ecs]
}

resource "aws_lb" "api" {
  name               = var.workload_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
}

resource "aws_lb_target_group" "api" {
  name        = "${var.workload_name}-api"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/ready"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.workload_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.runtime_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "api"
    image     = var.api_image_uri
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_ENV", value = "cert" },
      { name = "AWS_CERTIFICATION_ENABLED", value = "1" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "API_BIND_ADDR", value = "0.0.0.0:8080" },
      { name = "MOCK_TRANSFER_AGENT_URL", value = "http://mock-transfer-agent.${aws_service_discovery_private_dns_namespace.main.name}:8090" }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["api"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "worker" {
  for_each                 = toset(["outbox-publisher", "transfer-agent", "reconciliation", "chain-watcher", "notification"])
  family                   = "${var.workload_name}-${each.value}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.runtime_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "worker"
    image     = var.worker_image_uri
    essential = true
    environment = [
      { name = "APP_ENV", value = "cert" },
      { name = "AWS_CERTIFICATION_ENABLED", value = "1" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "WORKER_KIND", value = each.value },
      { name = "SNS_TOPIC_ARN", value = aws_sns_topic.domain_events.arn },
      { name = "MOCK_TRANSFER_AGENT_URL", value = "http://mock-transfer-agent.${aws_service_discovery_private_dns_namespace.main.name}:8090" },
      { name = "SQS_TRANSFER_AGENT_QUEUE_URL", value = aws_sqs_queue.worker["transfer-agent"].id },
      { name = "SQS_RECONCILIATION_QUEUE_URL", value = aws_sqs_queue.worker["reconciliation"].id },
      { name = "SQS_CHAIN_WATCHER_QUEUE_URL", value = aws_sqs_queue.worker["chain-watcher"].id },
      { name = "SQS_NOTIFICATION_QUEUE_URL", value = aws_sqs_queue.worker["notification"].id }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["worker"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = each.value
      }
    }
  }])
}

resource "aws_ecs_task_definition" "mock_transfer_agent" {
  family                   = "${var.workload_name}-mock-transfer-agent"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.runtime_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "mock-transfer-agent"
    image     = var.mock_transfer_agent_image_uri
    essential = true
    portMappings = [{
      containerPort = 8090
      protocol      = "tcp"
    }]
    environment = [
      { name = "MOCK_TRANSFER_AGENT_BIND_ADDR", value = "0.0.0.0:8090" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["mock-transfer-agent"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "mock-transfer-agent"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "certifier" {
  family                   = "${var.workload_name}-certifier"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.runtime_cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "certifier"
    image     = var.certifier_image_uri
    essential = true
    environment = [
      { name = "APP_ENV", value = "cert" },
      { name = "AWS_CERTIFICATION_ENABLED", value = "1" },
      { name = "AWS_REGION", value = var.aws_region }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service["certifier"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "certifier"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  propagate_tags  = "SERVICE"

  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_lb_listener.api
  ]
}

resource "aws_ecs_service" "mock_transfer_agent" {
  name            = "mock-transfer-agent"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mock_transfer_agent.arn
  desired_count   = 1
  propagate_tags  = "SERVICE"

  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mock_transfer_agent.arn
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}

resource "aws_ecs_service" "worker" {
  for_each        = toset(["outbox-publisher", "transfer-agent", "reconciliation", "chain-watcher", "notification"])
  name            = each.value
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker[each.value].arn
  desired_count   = var.worker_desired_count
  propagate_tags  = "SERVICE"

  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count]
  }

  enable_execute_command = false

  depends_on = [aws_ecs_cluster_capacity_providers.main]

  tags = {
    WorkerKind = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible" {
  for_each            = local.worker_queues
  alarm_name          = "${var.workload_name}-${each.key}-dlq-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.dlq[each.key].name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.workload_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
  }
}

resource "aws_iam_role" "fis" {
  name = "${var.workload_name}-fis"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "fis.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "fis" {
  name = "${var.workload_name}-fis"
  role = aws_iam_role.fis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:StopTask",
        "tag:GetResources"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_fis_experiment_template" "stop_worker_task" {
  description = "Stop one ECS worker task to test at-least-once delivery and replacement behavior"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  target {
    name           = "worker-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "CertificationWorkstream"
      value = "aws-simulation"
    }
  }

  action {
    name      = "stop-worker-task"
    action_id = "aws:ecs:stop-task"

    target {
      key   = "Tasks"
      value = "worker-tasks"
    }
  }
}

resource "aws_budgets_budget" "campaign" {
  name         = "${var.workload_name}-${var.budget_limit_usd}-usd"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.budget_notification_email == "" ? [] : [var.budget_notification_email]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [notification.value]
    }
  }
}
