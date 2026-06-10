locals {
  # Boolean logic to toggle resource creation based on connection type
  private_mode = var.is_private_connection ? { "enabled" : true } : {}
  public_mode  = !var.is_private_connection ? { "enabled" : true } : {}
  is_public_ip = !var.is_private_connection
  mode         = var.is_private_connection ? "private" : "public"
}

# 1. Creation of a standalone VPC for the Database
resource "aws_vpc" "rds_vpc" {
  cidr_block           = var.rds_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "rds-vpc-${var.environment}" }
}

# Fetch available Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnets dynamically based on the configuration map
resource "aws_subnet" "subnets" {
  for_each   = var.rds_subnets_config
  vpc_id     = aws_vpc.rds_vpc.id
  cidr_block = each.value
  # Distribute subnets across available AZs using modular arithmetic
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.rds_subnets_config), each.key) % length(data.aws_availability_zones.available.names)]

  # Logic: Production environments should ideally be Private. 
  # Use VPN or Bastion for access instead of Public IPs on the DB.
  map_public_ip_on_launch = local.is_public_ip

  tags = { Name = "subnet-${each.key}" }
}

# Group subnets for RDS usage
resource "aws_db_subnet_group" "main" {
  name       = "rds-subnet-group-${var.environment}"
  subnet_ids = [for s in aws_subnet.subnets : s.id]
}

# 3. Security Group for the DATABASE (RDS & Proxy)
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allows access to RDS"
  vpc_id      = aws_vpc.rds_vpc.id
}

# Egress: Allow all outbound traffic
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}



################### Public Ingress ######################################

# Rule to allow the Orchestrator IP access in Public Mode
resource "aws_security_group_rule" "public_orch_ingress" {
  for_each          = local.public_mode
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.orch_ip
  security_group_id = aws_security_group.rds_sg.id
}

# General public access rule (Used for serverless access in public mode)
resource "aws_security_group_rule" "public_access_ingress" {
  for_each          = local.public_mode
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}

################# Public Route Table and IGW ##################################

# Internet Gateway for public database reachability
resource "aws_internet_gateway" "igw" {
  for_each = local.public_mode
  vpc_id   = aws_vpc.rds_vpc.id
}

# Public Route Table directing 0.0.0.0/0 to the IGW
resource "aws_route_table" "rt" {
  for_each = local.public_mode
  vpc_id   = aws_vpc.rds_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[each.key].id
  }
}

# Associate subnets with the public route table if not in private mode
resource "aws_route_table_association" "rta" {
  for_each       = var.is_private_connection ? {} : aws_subnet.subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt["enabled"].id
}


################## Private RDS SG Ingress #####################################

# In Private Mode: DB accepts traffic ONLY from the Fargate Gateway Security Group
resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  for_each                 = local.private_mode
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg["enabled"].id
  security_group_id        = aws_security_group.rds_sg.id
}

# Allow RDS Proxy to communicate with the Database (Self-reference)
resource "aws_security_group_rule" "rds_self_ingress" {
  for_each                 = local.private_mode
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.rds_sg.id
}

#################### ECS Security Group #######################################

# Security Group for the GATEWAY (Fargate / PgBouncer)
resource "aws_security_group" "ecs_sg" {
  for_each    = local.private_mode
  name        = "ecs-gateway-sg"
  description = "Allows access to PgBouncer from NLB"
  vpc_id      = aws_vpc.rds_vpc.id
}

# Inbound: Fargate accepts traffic on 5432 from the entire VPC (for NLB health checks/traffic)
resource "aws_security_group_rule" "ecs_ingress" {
  for_each          = local.private_mode
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.rds_vpc.cidr_block]
  security_group_id = aws_security_group.ecs_sg["enabled"].id
}

# Inbound HTTPS: Required for VPC Endpoints to function
resource "aws_security_group_rule" "ecs_https_ingress" {
  for_each          = local.private_mode
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.rds_vpc.cidr_block]
  security_group_id = aws_security_group.ecs_sg["enabled"].id
}

# Outbound: Allow all for ECS
resource "aws_security_group_rule" "ecs_egress" {
  for_each          = local.private_mode
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sg["enabled"].id
}



#################### VPC Endpoints ############################################

# 1. Interface Endpoint for Secrets Manager (Secure credentials retrieval)
resource "aws_vpc_endpoint" "secretsmanager" {
  for_each            = local.private_mode
  vpc_id              = aws_vpc.rds_vpc.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [for s in aws_subnet.subnets : s.id]
  security_group_ids = [aws_security_group.ecs_sg["enabled"].id]
}

# 2. Interface Endpoint for CloudWatch Logs (Logging without IGW)
resource "aws_vpc_endpoint" "logs" {
  for_each            = local.private_mode
  vpc_id              = aws_vpc.rds_vpc.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [for s in aws_subnet.subnets : s.id]
  security_group_ids = [aws_security_group.ecs_sg["enabled"].id]
}

# 3. VPC Endpoints for ECR (Set of 3 required for private image pulls)
resource "aws_vpc_endpoint" "ecr_api" {
  for_each            = local.private_mode
  vpc_id              = aws_vpc.rds_vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.subnets : s.id]
  security_group_ids  = [aws_security_group.ecs_sg["enabled"].id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  for_each            = local.private_mode
  vpc_id              = aws_vpc.rds_vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.subnets : s.id]
  security_group_ids  = [aws_security_group.ecs_sg["enabled"].id]
}

# S3 Gateway Endpoint: Required because ECR stores image layers in S3
resource "aws_vpc_endpoint" "s3" {
  for_each          = local.private_mode
  vpc_id            = aws_vpc.rds_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.rds_vpc.main_route_table_id]
}