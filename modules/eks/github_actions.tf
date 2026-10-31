locals {
  github_actions_oidc_issuer = "https://token.actions.githubusercontent.com"
  ecr_repository_prefix      = "${var.name}-${var.environment}-services"
}

data "tls_certificate" "github_actions" {
  url = local.github_actions_oidc_issuer
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = local.github_actions_oidc_issuer

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[
      length(data.tls_certificate.github_actions.certificates) - 1
    ].sha1_fingerprint
  ]
}

resource "aws_security_group" "github_actions_runner" {
  name        = "${var.name}-${var.environment}-github-actions-runner"
  description = "Network identity for the private GitHub Actions EKS deployment runner"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-github-actions-runner"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
    Role        = "GitHubActionsRunner"
  })
}

resource "aws_vpc_security_group_egress_rule" "github_actions_runner_outbound" {
  security_group_id = aws_security_group.github_actions_runner.id
  description       = "Allow the self-hosted runner to reach GitHub and AWS APIs through the VPC egress path"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "github_actions_runner_to_eks" {
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.github_actions_runner.id
  description                  = "Allow the private GitHub Actions runner to reach the EKS API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
