data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-${var.environment}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-cluster-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSCluster"
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-${var.environment}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-node-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSWorkerNode"
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_pull" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    sid     = "AllowEksPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_cni_pod_identity" {
  name               = "${var.name}-${var.environment}-vpc-cni-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-vpc-cni-pod-identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSVPCCNIPodIdentity"
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni_pod_identity" {
  role       = aws_iam_role.vpc_cni_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role" "ebs_csi_pod_identity" {
  name               = "${var.name}-${var.environment}-ebs-csi-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-ebs-csi-pod-identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSEBSCSIPodIdentity"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_pod_identity" {
  role       = aws_iam_role.ebs_csi_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

# Temporary bootstrap permission.
# Remove after the VPC CNI Pod Identity association is verified.
resource "aws_iam_role_policy_attachment" "node_cni_bootstrap" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


# Dedicated human administrator role for EKS access.
data "aws_iam_policy_document" "eks_admin_assume_role" {
  statement {
    sid     = "AllowPlatformOperator"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.eks_admin_user_arn]
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  name                 = "${var.name}-${var.environment}-eks-admin"
  assume_role_policy   = data.aws_iam_policy_document.eks_admin_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-admin"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "EKSHumanAdministrator"
  })
}
