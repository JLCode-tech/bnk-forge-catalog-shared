# modules/foundation/vpc/main.tf
# VPC module - inherits versions/providers from version

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with project-specific name
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# 5 Subnets as specified
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-jumphost"
    Type = "Public"
  })
}

resource "aws_subnet" "private_external_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_external_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-external-a"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_external_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_external_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-external-b"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_internal_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_internal_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-internal-a"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  })
}

resource "aws_subnet" "private_internal_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_internal_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-internal-b"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_external_a" {
  subnet_id      = aws_subnet.private_external_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_external_b" {
  subnet_id      = aws_subnet.private_external_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_internal_a" {
  subnet_id      = aws_subnet.private_internal_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_internal_b" {
  subnet_id      = aws_subnet.private_internal_b.id
  route_table_id = aws_route_table.private.id
}