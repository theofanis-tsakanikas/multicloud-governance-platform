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
        { name = "DB_NAME", value = var.db_name },
        { name = "AUTH_TYPE", value = "scram-sha-256" },
        { name = "POOL_MODE", value = "transaction" },
        { name = "MAX_CLIENT_CONN", value = "1000" },

        # The instance itself, for the image's one-shot roles. A private RDS has no public
        # address and admits only this task's security group, so schema DDL and the seed have
        # nowhere else to run from — the same image, the same subnet, `aws ecs run-task`.
        # The gateway role ignores this and goes through the proxy.
        { name = "RDS_HOST", value = var.rds_hostname },
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

  # Without this the apply returns the moment ECS *accepts* the service, not when it works. A
  # missing image, a container that exits, a target group that never goes healthy — all of it
  # happens after Terraform has already reported success, and the private path is then dead
  # behind a green deploy. Wait for steady state and those failures land where they belong.
  wait_for_steady_state = true

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pgbouncer_tg.arn
    container_name   = "pgbouncer"
    container_port   = 5432
  }

  # Terraform's implicit graph gives the service the target group's ARN but knows nothing about
  # the listener. ECS then rejects the registration outright: "The target group does not have an
  # associated load balancer."
  depends_on = [aws_lb_listener.pgbouncer_listener]
}

# 8. VPC Endpoint Service (The PrivateLink)
resource "aws_vpc_endpoint_service" "rds_ncc_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn] # Link to the NLB created above

  tags = {
    Name = "rds-ncc-service-${var.environment}"
  }
}

# Allowed Principal — who may put an endpoint into this service.
#
# This was `"*"`. Alongside acceptance_required = false that meant *any* AWS account in the
# region could create an interface endpoint into this NLB, reach the gateway, and speak Postgres
# to a database whose entire reason for being private is that nobody should.
#
# It also would not have worked. Databricks does not merely need permission — its API validates
# the allow-list before it will even attempt the endpoint, and it looks for one exact ARN:
#
#   NOT_FOUND: Cannot find VPC Endpoint Service ... This could indicate: (2) The VPC Endpoint
#   Service's 'Allowed Principals' list does not include the Databricks's
#   'private-connectivity-role' Role ARN.
#
# A wildcard is not that string, so `"*"` fails the check too. The tightest grant and the only
# working one are the same grant: the single role, in Databricks' own AWS account, that
# serverless compute creates its private endpoints from.
locals {
  # Region-suffixed, and in Databricks' *serverless PrivateLink* account — which is not the
  # account the workspace cross-account role lives in. Both mistakes fail identically, with an
  # error that names the endpoint service and not the ARN it could not find.
  databricks_private_connectivity_role = "arn:aws:iam::${var.databricks_serverless_privatelink_account_id}:role/private-connectivity-role-${var.region}"
}

resource "aws_vpc_endpoint_service_allowed_principal" "databricks" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.rds_ncc_service.id
  principal_arn           = local.databricks_private_connectivity_role
}

# ── The teardown, which the endpoint service cannot do alone ──────────────────────────────────
#
# Deleting the NCC rule removes it from Databricks' config immediately — and leaves Databricks' actual
# VPC endpoint standing in Databricks' own AWS account, still connected to this service. AWS will not
# delete an endpoint service that has a live connection, so the destroy dies:
#
#     Error: deleting EC2 VPC Endpoint Service (vpce-svc-...): ... has active connections
#
# The GCP hub's teardown proved this is not a race that waiting wins: twenty minutes after the rule
# was gone, the endpoint was still `available`.
#
# But a connection belongs to two parties, and the service owner may reject one — and a rejected
# endpoint is one AWS will let go of. So reject whatever is attached, on the way out.
#
# The ordering is the whole safety argument. This resource reads the service's id, so Terraform
# destroys it BEFORE the service; and the NCC rule module consumes this module's output, so Terraform
# destroys the rule before either. By the time the rejection lands, the rule is already gone and there
# is nothing left that could re-establish the connection.
resource "null_resource" "drain_endpoint_connections" {
  triggers = {
    service_id = aws_vpc_endpoint_service.rds_ncc_service.id
    region     = var.region
  }

  provisioner "local-exec" {
    when = destroy
    # Backticks live inside the single-quoted JMESPath, where the shell leaves them alone.
    command = <<-EOT
      set -eu
      IDS=$(aws ec2 describe-vpc-endpoint-connections --region ${self.triggers.region} \
              --filters "Name=service-id,Values=${self.triggers.service_id}" \
              --query 'VpcEndpointConnections[?VpcEndpointState==`available` || VpcEndpointState==`pendingAcceptance`].VpcEndpointId' \
              --output text)
      if [ -n "$IDS" ]; then
        echo "draining endpoint connections from ${self.triggers.service_id}: $IDS"
        aws ec2 reject-vpc-endpoint-connections --region ${self.triggers.region} \
          --service-id ${self.triggers.service_id} --vpc-endpoint-ids $IDS
      else
        echo "no endpoint connections on ${self.triggers.service_id} — nothing to drain"
      fi
    EOT
  }
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