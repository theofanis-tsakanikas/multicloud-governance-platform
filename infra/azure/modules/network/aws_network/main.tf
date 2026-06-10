# Fetches all available availability zones in the provider's defined region
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. The Network (VPC & Subnets)
# The Virtual Private Cloud
resource "aws_vpc" "databricks_vpc" {
  cidr_block           = var.databricks_vpc_cidr # e.g., "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "databricks-private-vpc" }
}



# The Private Subnets
resource "aws_subnet" "private_subnets" {
  for_each   = var.databricks_subnets
  vpc_id     = aws_vpc.databricks_vpc.id
  cidr_block = each.value
  # Determines the AZ based on the index of the current key in the map
  availability_zone = data.aws_availability_zones.available.names[
    index(keys(var.databricks_subnets), each.key)
  ]

  tags = {
    Name = "databricks-${each.key}"
    # Required tag for Databricks to identify where to provision compute nodes
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# 2. Security Groups (The Firewall)
resource "aws_security_group" "databricks_sg" {
  name   = "databricks-worker-sg"
  vpc_id = aws_vpc.databricks_vpc.id

  # Allow all internal traffic (Inbound from self)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1" # Represents "All protocols" (TCP, UDP, etc.)
    self      = true
  }

  # Allow all outbound traffic (Egress)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.databricks_vpc.id
  tags   = { Name = "databricks-private-rt" }
}

# Associate the Route Table with the Private Subnets
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# 3. VPC Endpoints (Zero Internet Exposure for Core Services)
# S3 Gateway Endpoint (For data access and root storage)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.databricks_vpc.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.private.id]
}



# STS Interface Endpoint (For IAM Roles/Authentication)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.databricks_vpc.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private_subnets : s.id]
  security_group_ids  = [aws_security_group.databricks_sg.id]
  private_dns_enabled = true
}

# Kinesis Interface Endpoint (Isolation for data streams)
resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = aws_vpc.databricks_vpc.id
  service_name        = "com.amazonaws.${var.region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private_subnets : s.id]
  security_group_ids  = [aws_security_group.databricks_sg.id]
  private_dns_enabled = true
}

# 4. The Bridge to Azure (VPN Gateway)
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.databricks_vpc.id

  tags = { Name = "gateway-to-azure" }
}

# Route to Azure via the VPN Gateway
resource "aws_route" "to_azure" {
  for_each = toset(var.azure_vnet_cidr)

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = each.value
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}

# Internet Gateway for the VPC (Required for NAT Gateway)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.databricks_vpc.id
  tags   = { Name = "databricks-igw" }
}

# Small Public Subnet exclusively for the NAT Gateway
resource "aws_subnet" "public_nat_subnet" {
  vpc_id            = aws_vpc.databricks_vpc.id
  cidr_block        = "10.10.100.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "databricks-public-nat-subnet" }
}

# Public Route Table (Outbound to Internet via IGW)
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

# NAT Gateway for controlled outbound access from Private Subnets
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_nat_subnet.id # Must reside in the Public Subnet
  tags          = { Name = "databricks-nat-gw" }

  # Ensures clean destruction order
  depends_on = [aws_internet_gateway.igw]
}

# Default route for Private Subnets to reach the Internet via NAT Gateway
resource "aws_route" "default_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}