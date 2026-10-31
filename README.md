# Internal Developer Platform

This repository contains the AWS foundation and Backstage portal for an
internal developer platform:

- `environments/dev` provisions networking, an EKS cluster, application and
  database security groups, an RDS DB subnet group, GitHub Actions OIDC access,
  and the ECR repository prefix for generated services.
- `modules` contains reusable networking, EKS, and security modules.
- `backstage` contains the developer portal and the Node.js/PostgreSQL
  scaffolder template.

## Provision the AWS foundation

Requirements: Terraform 1.9+, AWS CLI credentials authorized to create the
resources in the dev stack, and an existing VPC with an internet gateway.

From the repository root:

```powershell
Copy-Item environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Edit terraform.tfvars with your GitHub owner, VPC, gateway, admin identity, region and subnet CIDRs.
terraform -chdir=environments/dev init
terraform -chdir=environments/dev fmt -check
terraform -chdir=environments/dev validate
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

The stack creates NAT gateways and an EKS cluster, which incur AWS charges.
Review the plan and configure a shared remote Terraform state backend before
using this stack with a team. Do not commit `terraform.tfvars`, state files, or
AWS credentials.

Retrieve the values required by the Backstage template:

```powershell
terraform -chdir=environments/dev output -raw database_subnet_group_name
terraform -chdir=environments/dev output -raw database_security_group_id
terraform -chdir=environments/dev output -raw cluster_name
terraform -chdir=environments/dev output -raw github_actions_oidc_provider_arn
terraform -chdir=environments/dev output -raw ecr_repository_prefix
terraform -chdir=environments/dev output -raw github_actions_runner_security_group_id
terraform -chdir=environments/dev output -raw aws_region
terraform -chdir=environments/dev output -raw aws_account_id
terraform -chdir=environments/dev output -raw github_owner
```

The database security group permits PostgreSQL traffic from the application
security group attached to EKS nodes. Keep the database subnet group and
security group in the same VPC and region. Set `github_owner` to the GitHub
user or organization where Backstage publishes service repositories. Backstage
creates a separate IAM deployment role for each repository, with OIDC trust
restricted to that exact repository's `main` branch.

Each deployment role can publish images only to that service's ECR repository
and authenticates to EKS as a group bound only in that service's namespace.
Keep the EKS API CIDR restrictions in place: configure a self-hosted GitHub
Actions runner with the `eks-deployer` label inside the VPC so it can reach the
private EKS endpoint. Attach the security group returned by
`github_actions_runner_security_group_id` to its EC2 instance. Register the
runner using GitHub's generated setup commands and add the `eks-deployer`
label. The runner needs Docker, AWS CLI v2, `kubectl`, and `jq`.

## Configure Crossplane and Backstage

Follow [`backstage/README.md`](./backstage/README.md) to install Crossplane on
the EKS cluster, configure its AWS provider credentials, start Backstage, and
configure the self-hosted GitHub Actions runner in the VPC.

When a developer uses the Backstage template, its backend creates a namespace
and namespace-scoped deployment RoleBinding, creates a repository-specific IAM
role and EKS access entry, then applies the service's RDS `Instance` through
Crossplane. The GitHub Actions workflow runs tests for pushes and pull
requests; on `main`, the VPC runner builds and pushes an immutable image to
that service's ECR repository and deploys it to EKS. Protect Backstage's AWS
and Kubernetes identities and database secrets; do not put credentials in the
repository.
