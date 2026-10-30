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
