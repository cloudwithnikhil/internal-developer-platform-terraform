variable "aws_region" {
  description = "AWS region for the platform infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "platform_name" {
  description = "Name prefix for platform infrastructure"
  type        = string
  default     = "internal-developer-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the generated service repositories"
  type        = string
  default     = "cloudwithnikhil"

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_owner))
    error_message = "Provide a valid GitHub username or organization name."
  }
}

variable "vpc_id" {
  description = "Existing AWS VPC ID"
  type        = string
}

variable "internet_gateway_id" {
  description = "Existing Internet Gateway attached to the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet CIDRs keyed by Availability Zone"
  type        = map(string)
}

variable "private_app_subnets" {
  description = "Private EKS application subnet CIDRs keyed by Availability Zone"
  type        = map(string)
}

variable "database_subnets" {
  description = "Isolated RDS subnet CIDRs keyed by Availability Zone"
  type        = map(string)
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
