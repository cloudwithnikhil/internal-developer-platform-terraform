variable "name" {
  description = "Name prefix for EKS resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}


variable "eks_admin_user_arn" {
  description = "IAM user ARN trusted to assume the dedicated EKS administrator role"
  type        = string

  validation {
    condition = can(regex(
      "^arn:[^:]+:iam::[0-9]{12}:user/.+$",
      var.eks_admin_user_arn
    ))
    error_message = "Provide a valid IAM user ARN for the EKS administrator."
  }
}

variable "github_owner" {
  description = "GitHub user or organization allowed to assume the deployment role"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_owner))
    error_message = "Provide a valid GitHub username or organization name."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.37"
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private application subnet IDs across at least two AZs"
  type        = list(string)

  validation {
    condition = (
      length(var.private_subnet_ids) >= 2 &&
      length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    )
    error_message = "Provide at least two distinct private subnet IDs."
  }
}

variable "application_security_group_id" {
  description = "Existing application security group attached to EKS worker nodes"
  type        = string
}

variable "public_access_cidrs" {
  description = "Administrator public IPv4 CIDRs allowed to access the EKS API"
  type        = list(string)

  validation {
    condition = (
      length(var.public_access_cidrs) > 0 &&
      alltrue([
        for cidr in var.public_access_cidrs :
        can(cidrnetmask(cidr)) && endswith(cidr, "/32")
      ])
    )
    error_message = "Provide one or more valid IPv4 /32 CIDRs. Broad CIDR ranges are not allowed."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Worker node root volume size in GiB"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags for EKS resources"
  type        = map(string)
  default     = {}
}






variable "eks_addon_versions" {
  description = "Pinned versions of EKS managed add-ons compatible with the cluster Kubernetes version"
  type        = map(string)

  default = {
    vpc-cni                = "v1.22.4-eksbuild.10"
    coredns                = "v1.14.7-eksbuild.22"
    kube-proxy             = "v1.37.0-eksbuild.32"
    eks-pod-identity-agent = "v1.4.1-eksbuild.3"
    aws-ebs-csi-driver     = "v1.67.2-eksbuild.1"
  }

  validation {
    condition = alltrue([
      for addon in [
        "vpc-cni",
        "coredns",
        "kube-proxy",
        "eks-pod-identity-agent",
        "aws-ebs-csi-driver"
      ] : contains(keys(var.eks_addon_versions), addon) &&
      length(trimspace(lookup(var.eks_addon_versions, addon, ""))) > 0
    ])

    error_message = "All five required EKS add-on versions must be specified."
  }
}
