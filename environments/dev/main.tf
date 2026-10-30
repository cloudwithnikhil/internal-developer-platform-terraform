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
