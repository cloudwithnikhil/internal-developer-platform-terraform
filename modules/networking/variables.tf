
variable "name" {
  description = "Name prefix for networking resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for networking resources"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the existing Internet Gateway attached to the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet CIDRs keyed by Availability Zone"
  type        = map(string)

  validation {
    condition     = length(var.public_subnets) == 2
    error_message = "Exactly two public subnets are required."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.public_subnets) : can(cidrnetmask(cidr))
    ])
    error_message = "Every public subnet must have a valid IPv4 CIDR block."
  }

  validation {
    condition = (
      sort(keys(var.public_subnets)) == sort(keys(var.private_app_subnets)) &&
      sort(keys(var.public_subnets)) == sort(keys(var.database_subnets))
    )
    error_message = "Public, private application, and database subnet maps must use identical Availability Zone keys."
  }

  validation {
    condition = length(distinct(concat(
      values(var.public_subnets),
      values(var.private_app_subnets),
      values(var.database_subnets)
    ))) == (
      length(var.public_subnets) +
      length(var.private_app_subnets) +
      length(var.database_subnets)
    )
    error_message = "Subnet CIDRs must not contain exact duplicates across subnet groups."
  }
}

variable "private_app_subnets" {
  description = "Private EKS application subnet CIDRs keyed by Availability Zone"
  type        = map(string)

  validation {
    condition     = length(var.private_app_subnets) == 2
    error_message = "Exactly two private application subnets are required."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.private_app_subnets) : can(cidrnetmask(cidr))
    ])
    error_message = "Every private application subnet must have a valid IPv4 CIDR block."
  }
}

variable "database_subnets" {
  description = "Isolated database subnet CIDRs keyed by Availability Zone"
  type        = map(string)

  validation {
    condition     = length(var.database_subnets) == 2
    error_message = "Exactly two database subnets are required."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.database_subnets) : can(cidrnetmask(cidr))
    ])
    error_message = "Every database subnet must have a valid IPv4 CIDR block."
  }
}

variable "aws_region" {
  description = "AWS region for regional VPC endpoints"
  type        = string
}
