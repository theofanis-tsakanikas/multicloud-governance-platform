# Fetches all available Availability Zones in the region defined by the provider
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. The Network (VPC & Subnets)
# The main VPC container
resource "aws_vpc" "databricks_vpc" {
  cidr_block           = var.databricks_vpc_cidr # e.g., "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "databricks-private-vpc" }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  for_each   = var.databricks_subnets
  vpc_id     = aws_vpc.databricks_vpc.id
  cidr_block = each.value

  # Map each subnet to a unique Availability Zone based on its index in the map
  availability_zone = data.aws_availability_zones.available.names[
    index(keys(var.databricks_subnets), each.key)
  ]

  tags = {
    Name = "databricks-${each.key}"
    # This tag is mandatory for Databricks to identify where to provision nodes
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# 2. Security Groups (The "Firewall")
resource "aws_security_group" "databricks_sg" {
  name   = "databricks-worker-sg"
  vpc_id = aws_vpc.databricks_vpc.id

  # Allow all internal traffic (Inbound) between nodes in the same group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1" # Represents "All Protocols" (TCP, UDP, etc.)
    self      = true
  }

  # Allow all outbound traffic to the internet/other services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating the Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.databricks_vpc.id
  tags   = { Name = "databricks-private-rt" }
}

# Associating the Route Table with the Private Subnets
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# 3. VPC Endpoints (Zero Internet Exposure)
# S3 Gateway Endpoint (For data access and root storage without leaving the AWS network)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.databricks_vpc.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.private.id]
}

# STS Interface Endpoint (For secure IAM Role/Authentication)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.databricks_vpc.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private_subnets : s.id]
  security_group_ids  = [aws_security_group.databricks_sg.id]
  private_dns_enabled = true
}

# Kinesis Interface Endpoint (The "cherry on top" for total isolation)
resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = aws_vpc.databricks_vpc.id
  service_name        = "com.amazonaws.${var.region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private_subnets : s.id]
  security_group_ids  = [aws_security_group.databricks_sg.id]
  private_dns_enabled = true
}

# 4. The Gateway to Azure (VPN Gateway)
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.databricks_vpc.id

  tags = { Name = "gateway-to-azure" }
}

# Route to GCP (via the VPN Gateway)
resource "aws_route" "to_gcp" {
  for_each = toset(var.gcp_vpc_cidr)

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}

# Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.databricks_vpc.id
  tags   = { Name = "databricks-igw" }
}

# A small Public Subnet specifically for the NAT Gateway
resource "aws_subnet" "public_nat_subnet" {
  vpc_id            = aws_vpc.databricks_vpc.id
  cidr_block        = "10.10.100.0/24" # A unique range not used elsewhere
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "databricks-public-nat-subnet" }
}

# Route Table for the Public Subnet (directed to the Internet)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.databricks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_nat_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_nat_subnet.id # Placed in the Public subnet
  tags          = { Name = "databricks-nat-gw" }

  # Ensures smooth destruction sequence
  depends_on = [aws_internet_gateway.igw]
}

# Default route for the Private Subnets to reach the internet via NAT Gateway
resource "aws_route" "default_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}