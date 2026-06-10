# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "db-gateway-cluster-${var.environment}"
}

# 2. Network Load Balancer (NLB)
# The NLB is required for AWS PrivateLink integration
resource "aws_lb" "nlb" {
  name               = "rds-gateway-nlb-${var.environment}"
  internal           = true # Always internal for PrivateLink usage
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = true
}

# 3. Target Group for the NLB
resource "aws_lb_target_group" "pgbouncer_tg" {
  name        = "pgbouncer-tg-${var.environment}"
  port        = 5432
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate compatibility

  health_check {
    protocol            = "TCP"
    port                = "5432"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# 4. Listener for the NLB
resource "aws_lb_listener" "pgbouncer_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pgbouncer_tg.arn
  }
}



# CloudWatch Logging Group
resource "aws_cloudwatch_log_group" "pgbouncer" {
  name              = "/ecs/pgbouncer-${var.environment}"
  retention_in_days = 1 # Log retention set to 1 day for cost optimization

  tags = {
    Environment = var.environment
  }
}

# 5. RDS Proxy
# Manages connection pooling and improves database scalability
resource "aws_db_proxy" "rds_proxy" {
  name                   = "rds-proxy-${var.environment}"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = var.proxy_role_arn
  vpc_security_group_ids = [var.rds_security_group_id]
  vpc_subnet_ids         = var.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "RDS Credentials from Secrets Manager"
    iam_auth    = "DISABLED"
    secret_arn  = var.rds_secret_arn
  }
}

resource "aws_db_proxy_target" "rds_target" {
  db_instance_identifier = var.db_instance_identifier
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = "default"
}

# Helper to fetch the current AWS Account ID
data "aws_caller_identity" "current" {}

# 6. ECS Task Definition (The PgBouncer "Recipe")
resource "aws_ecs_task_definition" "pgbouncer" {
  family                   = "pgbouncer-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_role_arn

  container_definitions = jsonencode([
    {
      name  = "pgbouncer"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repo_name}:latest"
      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_proxy.rds_proxy.endpoint },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_USER", value = var.rds_username },
        { name = "AUTH_TYPE", value = "scram-sha-256" },
        { name = "POOL_MODE", value = "transaction" },
        { name = "MAX_CLIENT_CONN", value = "1000" }
      ]
      secrets = [
        {
          name = "DB_PASSWORD"
          # Extracting only the "password" field from the JSON Secret
          valueFrom = "${var.rds_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/pgbouncer-${var.environment}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 7. ECS Service (Ensures the Task remains running)
resource "aws_ecs_service" "main" {
  name            = "pgbouncer-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.pgbouncer.arn
  desired_count   = 1 # Increase for High Availability (HA)
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pgbouncer_tg.arn
    container_name   = "pgbouncer"
    container_port   = 5432
  }
}

# 8. VPC Endpoint Service (The PrivateLink)
resource "aws_vpc_endpoint_service" "rds_ncc_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn] # Link to the NLB created above

  tags = {
    Name = "rds-ncc-service-${var.environment}"
  }
}

# Allowed Principal (Permissions for connection)
resource "aws_vpc_endpoint_service_allowed_principal" "databricks" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.rds_ncc_service.id

  # Set to "*" to allow any principal, or replace with specific ARNs for locking down security
  principal_arn = "*"
}

# Route 53 Private DNS Configuration
# 1. Private Hosted Zone creation
resource "aws_route53_zone" "private" {
  name = var.private_dns_zone_name
  vpc {
    vpc_id = var.vpc_id
  }
}

# 2. DNS Record pointing to the NLB
resource "aws_route53_record" "rds_dns" {
  zone_id = aws_route53_zone.private.zone_id
  name    = var.rds_custom_dns_name # This becomes your new private Hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.nlb.dns_name]
}