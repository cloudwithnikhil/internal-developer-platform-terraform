output "application_security_group_id" {
  description = "Security group ID for EKS application workloads"
  value       = aws_security_group.application.id
}

output "database_security_group_id" {
  description = "Security group ID for the private RDS database"
  value       = aws_security_group.database.id
}
