module "networking" {
  source = "../../modules/networking"

  name                = var.platform_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_id              = var.vpc_id
  internet_gateway_id = var.internet_gateway_id

  public_subnets      = var.public_subnets
  private_app_subnets = var.private_app_subnets
  database_subnets    = var.database_subnets
}
module "security" {
  source = "../../modules/security"

  name        = var.platform_name
  environment = var.environment
  vpc_id      = var.vpc_id
}

module "eks" {
  source = "../../modules/eks"

  name               = var.platform_name
  environment        = var.environment
  eks_admin_user_arn = "arn:aws:iam::129896630824:user/terraform-platform-operator"

  cluster_version = "1.37"

  vpc_id = var.vpc_id

  private_subnet_ids = values(module.networking.private_app_subnet_ids)

  application_security_group_id = module.security.application_security_group_id

  public_access_cidrs = var.public_access_cidrs

  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 2
  node_max_size       = 4
  node_disk_size      = 30

  tags = {
    Project     = var.platform_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
