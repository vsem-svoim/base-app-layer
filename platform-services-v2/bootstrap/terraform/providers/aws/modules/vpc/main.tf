# ===================================================================
# VPC Module for AWS Infrastructure
# ===================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_availability_zones" "available" {
  state = "available"
}

# ===================================================================
# Local Values
# ===================================================================
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.availability_zones))
  
  # Calculate subnet CIDRs dynamically
  private_subnet_cidrs  = [for i in range(var.private_subnets_count * length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  public_subnet_cidrs   = [for i in range(var.public_subnets_count * length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 101)]
  database_subnet_cidrs = [for i in range(var.database_subnets_count * length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 201)]
}

# ===================================================================
# VPC
# ===================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
    Type = "vpc"
  })
}

# ===================================================================
# Internet Gateway
# ===================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
    Type = "internet-gateway"
  })
}

# ===================================================================
# Private Subnets
# ===================================================================
resource "aws_subnet" "private" {
  count = var.private_subnets_count * length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index % length(local.azs)]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Type = "private-subnet"
    Tier = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ===================================================================
# Public Subnets
# ===================================================================
resource "aws_subnet" "public" {
  count = var.public_subnets_count * length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index % length(local.azs)]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public-subnet"
    Tier = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

# ===================================================================
# Database Subnets
# ===================================================================
resource "aws_subnet" "database" {
  count = var.database_subnets_count * length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index % length(local.azs)]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-${count.index + 1}"
    Type = "database-subnet"
    Tier = "database"
  })
}

# ===================================================================
# Elastic IPs for NAT Gateways
# ===================================================================
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.nat_gateway_count) : 0

  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Type = "nat-eip"
  })
}

# ===================================================================
# NAT Gateways
# ===================================================================
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.nat_gateway_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index % length(aws_subnet.public)].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-gateway-${count.index + 1}"
    Type = "nat-gateway"
  })
}

# ===================================================================
# Route Tables
# ===================================================================

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
    Type = "public-route-table"
  })
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 1

  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index % length(aws_nat_gateway.main)].id
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Type = "private-route-table"
  })
}

# Database Route Table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-rt"
    Type = "database-route-table"
  })
}

# ===================================================================
# Route Table Associations
# ===================================================================

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index % length(aws_route_table.private)].id
}

# Database Subnet Associations
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# ===================================================================
# VPC Endpoints for Cost Optimization
# ===================================================================

# S3 VPC Endpoint (Gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
    Type = "vpc-endpoint"
  })
}

# ECR VPC Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = slice([for subnet in aws_subnet.private : subnet.id], 0, length(local.azs))
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecr-api-endpoint"
    Type = "vpc-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = slice([for subnet in aws_subnet.private : subnet.id], 0, length(local.azs))
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
    Type = "vpc-endpoint"
  })
}

# ===================================================================
# Security Groups
# ===================================================================

# VPC Endpoints Security Group
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    Type = "security-group"
  })
}

# ===================================================================
# Data Sources for Region
# ===================================================================
data "aws_region" "current" {}