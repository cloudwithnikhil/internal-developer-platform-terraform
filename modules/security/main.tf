resource "aws_security_group" "application" {
  name        = "${var.name}-application-sg"
  description = "Security group for private EKS application workloads"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  tags = {
    Name        = "${var.name}-application-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "Application"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database-sg"
  description = "Private PostgreSQL access from approved application workloads"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  tags = {
    Name        = "${var.name}-database-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "Database"
  }
}

# Application workloads need outbound connectivity for EKS and AWS services.
# Network routing still controls the available paths through the private subnets.
resource "aws_vpc_security_group_egress_rule" "application_outbound" {
  security_group_id = aws_security_group.application.id

  description = "Allow application workloads outbound IPv4 connectivity"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# PostgreSQL is accessible only from workloads using the application SG.
resource "aws_vpc_security_group_ingress_rule" "postgres_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id

  description = "Allow PostgreSQL only from application workloads"
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}
