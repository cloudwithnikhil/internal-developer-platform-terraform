variable "name" {
  description = "Name prefix for security resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}
