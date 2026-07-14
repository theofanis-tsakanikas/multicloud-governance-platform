# The AWS end of the Azure SQL transit hub — the SQL-Server twin of aws/.../rds_gateway.
#
# Databricks serverless (an AWS Databricks account) reaches this over PrivateLink exactly as it
# reaches the RDS gateway; the difference is only what sits behind the NLB. Here it is an HAProxy
# TCP passthrough that forwards 1433 across the Site-to-Site VPN (built by the sibling
# aws_az_vpn_conn module) to Azure SQL's private endpoint. No pooler, no credential in the
# gateway — the TLS session is end-to-end between Databricks and Azure SQL.
#
#   NCC rule → aws_vpc_endpoint_service (PrivateLink) → aws_lb (NLB :1433) → ECS Fargate HAProxy
#            → VPN → Azure private endpoint → Azure SQL
#
# Lives in the AWS VPC that network/aws_network already builds for the tunnel (10.10.0.0/16),
# which has a NAT gateway — so the Fargate task pulls its image and writes logs over NAT, and no
# interface VPC endpoints are needed (unlike the RDS gateway, whose VPC has none).

resource "aws_ecs_cluster" "main" {
  name = "sql-gateway-cluster-${var.environment}"
}

# The Fargate task's own security group. aws_network's databricks_sg admits only itself
# (self = true), which blocks the NLB health check — it originates from the NLB's ENIs in the
# VPC subnets, not from that SG — and the PrivateLink-forwarded traffic too, both of which arrive
# from within the VPC. So the target group never goes healthy and wait_for_steady_state hangs.
# Admit 1433 from the VPC CIDR (the RDS gateway does the same for 5432).
resource "aws_security_group" "gateway" {
  name        = "sql-gateway-sg-${var.environment}"
  description = "SQL transit gateway: 1433 in from the VPC (NLB health checks + PrivateLink traffic)"
  vpc_id      = var.vpc_id

  ingress {
    description = "1433 from the transit VPC: the NLBs health checks and the PrivateLink traffic behind them"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound to Azure SQL across the IPsec tunnel, and to ECR/CloudWatch for the image and its logs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Internal NLB — the PrivateLink service can only front a network load balancer.
resource "aws_lb" "nlb" {
  name                             = "sql-gateway-nlb-${var.environment}"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "haproxy_tg" {
  # name_prefix + create_before_destroy, backported from bq_gateway: a target group's port is
  # immutable, so any port change REPLACES the group while the listener still references it
  # ("ResourceInUse: Target group ... in use by a listener"). name_prefix lets the replacement come
  # up under a fresh name and the listener repoint before the old group is destroyed. The fix was
  # learned on bq_gateway (443→8443) and is applied here before it can bite.
  name_prefix = "sqlgw-"
  port        = 1433
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate awsvpc networking registers by IP

  health_check {
    protocol            = "TCP"
    port                = "1433"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "haproxy_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "1433"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haproxy_tg.arn
  }
}

resource "aws_cloudwatch_log_group" "haproxy" {
  name              = "/ecs/sql-gateway-${var.environment}"
  retention_in_days = 1
  tags              = { Environment = var.environment }
}

# ── ECS task execution role — pull the image, write logs. No secret: the gateway holds none. ──
resource "aws_iam_role" "ecs_exec" {
  name = "sql-gateway-exec-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "haproxy" {
  family                   = "sql-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([
    {
      name  = "haproxy"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repo_name}:latest"
      portMappings = [
        { containerPort = 1433, hostPort = 1433, protocol = "tcp" }
      ]
      environment = [
        # The gateway role needs only the target. It resolves this FQDN through the VPC's Route53
        # zone (database.windows.net → private endpoint IP), created by aws_az_vpn_conn.
        { name = "TARGET_HOST", value = var.sql_server_fqdn },
        { name = "TARGET_PORT", value = "1433" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/sql-gateway-${var.environment}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "main" {
  name            = "sql-gateway-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.haproxy.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Same reason as the RDS gateway: without this the apply returns when ECS accepts the service,
  # not when the container is healthy — a missing image would hide behind a green deploy.
  wait_for_steady_state = true

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.gateway.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.haproxy_tg.arn
    container_name   = "haproxy"
    container_port   = 1433
  }

  # The graph gives the service the target group but not the listener; ECS rejects the
  # registration without it ("target group does not have an associated load balancer").
  depends_on = [aws_lb_listener.haproxy_listener]
}

# ── PrivateLink service — what the NCC rule points at ─────────────────────────────────────────
resource "aws_vpc_endpoint_service" "sql_ncc_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn]
  tags                       = { Name = "sql-ncc-service-${var.environment}" }
}

# Only Databricks' serverless-PrivateLink role may create an endpoint into this service. Same
# hard-won detail as the RDS gateway: the role is region-named and lives in a DIFFERENT Databricks
# AWS account than the workspace cross-account role, and Databricks validates this exact ARN on
# the allow-list before it will even attempt the endpoint.
resource "aws_vpc_endpoint_service_allowed_principal" "databricks" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.sql_ncc_service.id
  principal_arn           = "arn:aws:iam::${var.databricks_serverless_privatelink_account_id}:role/private-connectivity-role-${var.region}"
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
# destroys it BEFORE the service; and the sql_ncc_rule module consumes this module's output, so
# Terraform destroys the rule before either. By the time the rejection lands, the rule is already
# gone and there is nothing left that could re-establish the connection.
resource "null_resource" "drain_endpoint_connections" {
  triggers = {
    service_id = aws_vpc_endpoint_service.sql_ncc_service.id
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
