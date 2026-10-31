# EKS Pod Identity Agent
# Required before add-ons that use Pod Identity.

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.eks_addon_versions["eks-pod-identity-agent"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_node_group.this
  ]
}

# Amazon VPC CNI
# Uses the dedicated VPC CNI Pod Identity role.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = var.eks_addon_versions["vpc-cni"]

  pod_identity_association {
    role_arn        = aws_iam_role.vpc_cni_pod_identity.arn
    service_account = "aws-node"
  }

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_eks_node_group.this
  ]
}

# CoreDNS

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = var.eks_addon_versions["coredns"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_node_group.this
  ]
}

# kube-proxy

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = var.eks_addon_versions["kube-proxy"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_node_group.this
  ]
}

# AWS EBS CSI Driver
# Uses the dedicated EBS CSI Pod Identity role.

resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.eks_addon_versions["aws-ebs-csi-driver"]

  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi_pod_identity.arn
    service_account = "ebs-csi-controller-sa"
  }

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_eks_node_group.this
  ]
}