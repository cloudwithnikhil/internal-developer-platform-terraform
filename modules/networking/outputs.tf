output "public_subnet_ids" {
  description = "Public subnet IDs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.public : az => subnet.id
  }
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDRs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.public : az => subnet.cidr_block
  }
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.private_app : az => subnet.id
  }
}

output "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.private_app : az => subnet.cidr_block
  }
}

output "database_subnet_ids" {
  description = "Isolated database subnet IDs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.database : az => subnet.id
  }
}

output "database_subnet_cidrs" {
  description = "Isolated database subnet CIDRs keyed by Availability Zone"
  value = {
    for az, subnet in aws_subnet.database : az => subnet.cidr_block
  }
}

output "database_subnet_group_name" {
  description = "RDS DB subnet group name for the isolated database subnets"
  value       = aws_db_subnet_group.database.name
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "Private application route table IDs keyed by Availability Zone"
  value = {
    for az, route_table in aws_route_table.private_app : az => route_table.id
  }
}

output "database_route_table_ids" {
  description = "Isolated database route table IDs keyed by Availability Zone"
  value = {
    for az, route_table in aws_route_table.database : az => route_table.id
  }
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by Availability Zone"
  value = {
    for az, nat in aws_nat_gateway.az : az => nat.id
  }
}
