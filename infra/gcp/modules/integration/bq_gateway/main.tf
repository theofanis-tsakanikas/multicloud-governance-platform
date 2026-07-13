# The AWS end of the BigQuery transit hub — the third gateway, and the same shape as the other two.
#
#   NCC rule → aws_vpc_endpoint_service (PrivateLink) → aws_lb (NLB :443) → ECS Fargate HAProxy
#            → IPsec VPN → GCP VPC → private.googleapis.com VIP → BigQuery
#
# A pure TCP passthrough: it terminates nothing, holds no credential, and understands no protocol.
# The TLS session is end-to-end between Databricks and Google, and Google's frontend routes on the
# SNI the client sent — which is what lets one backend carry bigquery.googleapis.com,
# bigquerystorage.googleapis.com and oauth2.googleapis.com at the same time.
#
# Lives in GCP's own AWS transit VPC (10.11.0.0/16). It cannot share Azure's (10.10.0.0/16): that
# hub is live and carrying Azure SQL, and nothing here may touch it.

resource "aws_ecs_cluster" "main" {
  name = "bq-gateway-cluster-${var.environment}"
}

# The Fargate task's own security group, admitting 443 from the VPC.
#
# This is the Azure gateway's hardest-won lesson, applied before it can cost a run: the generic
# aws_network security group admits only itself (self = true), and NLB health checks originate from
# the load balancer's ENIs in the VPC subnets, not from that group. With the wrong SG the target
# never goes healthy, wait_for_steady_state hangs for twenty minutes, and the container logs show a
# perfectly healthy proxy the whole time.
resource "aws_security_group" "gateway" {
  name        = "bq-gateway-sg-${var.environment}"
  description = "BigQuery transit gateway: 443 in from the VPC (NLB health checks + PrivateLink traffic)"
  vpc_id      = var.vpc_id

  # 8443, not 443: HAProxy runs unprivileged and cannot bind below 1024. The NLB listens on 443
  # and forwards here, so the client still speaks 443 and nothing runs as root.
  ingress {
    description = "8443 from the transit VPC. Not 443: HAProxy runs unprivileged and cannot bind below 1024, so the NLB listens on 443 and forwards here"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound to Google's private API VIP across the IPsec tunnel, and to ECR/CloudWatch"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "nlb" {
  name                             = "bq-gateway-nlb-${var.environment}"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "haproxy_tg" {
  # A target group's port is immutable, so changing it replaces the group — and Terraform tries to
  # destroy the old one while the listener still points at it:
  #
  #     ResourceInUse: Target group ... is currently in use by a listener or a rule
  #
  # name_prefix + create_before_destroy is the way out: the replacement is built under a fresh
  # generated name, the listener is repointed at it, and only then does the old one go. A fixed
  # `name` cannot do this — the new group would collide with the old one it is replacing.
  name_prefix = "bqgw-"
  port        = 8443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "8443"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "haproxy_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haproxy_tg.arn
  }
}

resource "aws_cloudwatch_log_group" "haproxy" {
  name              = "/ecs/bq-gateway-${var.environment}"
  retention_in_days = 1
  tags              = { Environment = var.environment }
}

resource "aws_iam_role" "ecs_exec" {
  name = "bq-gateway-exec-${var.environment}"
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
  family                   = "bq-gateway"
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
        { containerPort = 8443, hostPort = 8443, protocol = "tcp" }
      ]
      environment = [
        # The private.googleapis.com addresses. The gateway reaches them by IP across the VPN —
        # no DNS is involved anywhere on this path, which is one less thing to be wrong.
        { name = "VIP_TARGETS", value = join(" ", var.private_api_vip_ips) },
        { name = "LISTEN_PORT", value = "8443" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/bq-gateway-${var.environment}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "main" {
  name            = "bq-gateway-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.haproxy.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # A missing image or an unhealthy target must fail the apply, not hide behind it.
  wait_for_steady_state = true

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.gateway.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.haproxy_tg.arn
    container_name   = "haproxy"
    container_port   = 8443
  }

  # The graph gives the service the target group but not the listener; ECS rejects the
  # registration without it.
  depends_on = [aws_lb_listener.haproxy_listener]
}

# ── PrivateLink service — what the NCC rule points at ─────────────────────────────────────────
resource "aws_vpc_endpoint_service" "bq_ncc_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn]
  tags                       = { Name = "bq-ncc-service-${var.environment}" }
}

# The one principal Databricks actually presents: a region-named role in its *serverless
# PrivateLink* account, which is not the account the workspace cross-account role lives in.
# Databricks validates this exact ARN on the allow-list before it will even attempt the endpoint,
# so a wildcard fails the check as surely as it fails the security review.
resource "aws_vpc_endpoint_service_allowed_principal" "databricks" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.bq_ncc_service.id
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
# Twenty minutes after the rule was gone, the endpoint was still `available`. Waiting is not a plan.
#
# But a connection belongs to two parties, and the service owner may reject one — and a rejected
# endpoint is one AWS will let go of. So reject whatever is attached, on the way out.
#
# The ordering is the whole safety argument. This resource reads the service's id, so Terraform
# destroys it BEFORE the service; and the bq_ncc_rule module consumes this module's output, so
# Terraform destroys the rule before either. By the time the rejection lands, the rule is already
# gone and there is nothing left that could re-establish the connection.
resource "null_resource" "drain_endpoint_connections" {
  triggers = {
    service_id = aws_vpc_endpoint_service.bq_ncc_service.id
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
