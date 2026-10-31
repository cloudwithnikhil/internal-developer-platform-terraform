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
