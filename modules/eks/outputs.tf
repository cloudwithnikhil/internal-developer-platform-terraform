output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group created by EKS for the cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Name of the managed worker node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN used by worker nodes"
  value       = aws_iam_role.node.arn
}

output "cluster_log_group_name" {
  description = "CloudWatch log group for EKS control-plane logs"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "github_actions_oidc_provider_arn" {
  description = "OIDC provider ARN used by per-repository GitHub deployment roles"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "ecr_repository_prefix" {
  description = "ECR repository name prefix used for generated services"
  value       = "${var.name}-${var.environment}-services"
}

output "aws_account_id" {
  description = "AWS account ID for generated service deployment roles"
  value       = data.aws_caller_identity.current.account_id
}

output "github_owner" {
  description = "GitHub owner trusted to publish generated service repositories"
  value       = var.github_owner
}

output "github_actions_runner_security_group_id" {
  description = "Security group to attach to the private GitHub Actions runner"
  value       = aws_security_group.github_actions_runner.id
}
