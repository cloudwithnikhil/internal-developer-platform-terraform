resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}-${var.environment}/cluster"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSControlPlaneLogs"
  })
}

resource "aws_eks_cluster" "this" {
  name     = "${var.name}-${var.environment}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSControlPlane"
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster
  ]
}
