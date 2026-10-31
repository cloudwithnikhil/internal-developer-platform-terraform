data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Public subnets: reserved for internet-facing load balancers.
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = data.aws_vpc.selected.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.name}-public-${each.key}"
    Environment              = var.environment
    ManagedBy                = "Terraform"
    Project                  = var.name
    Network                  = "Public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets: reserved for EKS application workloads.
resource "aws_subnet" "private_app" {
  for_each = var.private_app_subnets

  vpc_id                  = data.aws_vpc.selected.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.name}-private-app-${each.key}"
    Environment                       = var.environment
    ManagedBy                         = "Terraform"
    Project                           = var.name
    Network                           = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Isolated subnets: reserved for RDS and database resources.
resource "aws_subnet" "database" {
  for_each = var.database_subnets

  vpc_id                  = data.aws_vpc.selected.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.name}-database-${each.key}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Network     = "Isolated"
    Role        = "Database"
  }
}

resource "aws_db_subnet_group" "database" {
  name        = "${var.name}-${var.environment}-database"
  description = "Private database subnets for ${var.name}-${var.environment}"
  subnet_ids  = [for subnet in aws_subnet.database : subnet.id]

  tags = {
    Name        = "${var.name}-${var.environment}-database"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Network     = "Isolated"
    Role        = "Database"
  }
}

# Public routing through the existing Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name        = "${var.name}-public-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Network     = "Public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One Elastic IP and NAT Gateway in each Availability Zone.
resource "aws_eip" "nat" {
  for_each = var.private_app_subnets

  domain = "vpc"

  tags = {
    Name        = "${var.name}-nat-eip-${each.key}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
  }
}

resource "aws_nat_gateway" "az" {
  for_each = var.private_app_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [
    aws_route_table_association.public,
    aws_route.public_internet
  ]

  tags = {
    Name        = "${var.name}-nat-${each.key}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
  }
}

# Each application subnet uses the NAT Gateway in its own AZ.
resource "aws_route_table" "private_app" {
  for_each = var.private_app_subnets

  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name        = "${var.name}-private-app-rt-${each.key}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Network     = "Private"
  }
}

resource "aws_route" "private_app_nat" {
  for_each = var.private_app_subnets

  route_table_id         = aws_route_table.private_app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.az[each.key].id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

# Database route tables intentionally have no internet default route.
resource "aws_route_table" "database" {
  for_each = var.database_subnets

  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name        = "${var.name}-database-rt-${each.key}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Network     = "Isolated"
  }
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.key].id
}

# S3 Gateway Endpoint: private application subnets access S3 without NAT.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for route_table in aws_route_table.private_app : route_table.id
  ]

  tags = {
    Name        = "${var.name}-s3-gateway-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Service     = "S3"
  }
}
