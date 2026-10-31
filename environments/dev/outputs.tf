output "public_subnet_ids" {
  description = "Public subnet IDs keyed by Availability Zone"
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private EKS application subnet IDs keyed by Availability Zone"
  value       = module.networking.private_app_subnet_ids
}

output "database_subnet_ids" {
  description = "Isolated database subnet IDs keyed by Availability Zone"
  value       = module.networking.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "RDS DB subnet group name for the isolated database subnets"
  value       = module.networking.database_subnet_group_name
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = module.networking.public_route_table_id
}

output "private_app_route_table_ids" {
  description = "Private application route table IDs keyed by Availability Zone"
  value       = module.networking.private_app_route_table_ids
}

output "database_route_table_ids" {
  description = "Isolated database route table IDs keyed by Availability Zone"
  value       = module.networking.database_route_table_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by Availability Zone"
  value       = module.networking.nat_gateway_ids
}

output "application_security_group_id" {
  description = "Security group ID for EKS application workloads"
  value       = module.security.application_security_group_id
}

output "database_security_group_id" {
  description = "Security group ID for the private RDS database"
  value       = module.security.database_security_group_id
}

output "cluster_name" {
  description = "EKS cluster name for Crossplane and workload deployment"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "github_actions_oidc_provider_arn" {
  description = "OIDC provider ARN used by per-repository GitHub deployment roles"
  value       = module.eks.github_actions_oidc_provider_arn
}

output "ecr_repository_prefix" {
  description = "ECR repository name prefix used for generated services"
  value       = module.eks.ecr_repository_prefix
}

output "aws_account_id" {
  description = "AWS account ID for generated service deployment roles"
  value       = module.eks.aws_account_id
}

output "github_owner" {
  description = "GitHub owner trusted to publish generated service repositories"
  value       = module.eks.github_owner
}

output "github_actions_runner_security_group_id" {
  description = "Security group to attach to the private GitHub Actions runner"
  value       = module.eks.github_actions_runner_security_group_id
}

output "aws_region" {
  description = "AWS region used by the Terraform dev environment"
  value       = var.aws_region
}
