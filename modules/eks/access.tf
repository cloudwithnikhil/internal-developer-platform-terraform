resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-admin-access"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSHumanAdministratorAccess"
  })
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.eks_admin
  ]
}