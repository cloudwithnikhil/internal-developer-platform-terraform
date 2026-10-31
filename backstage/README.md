# Internal Developer Portal

This Backstage app includes a **Node.js Service with PostgreSQL** software
template. The template creates a GitHub repository containing a tested Node.js
service and GitHub Actions CI/CD workflow. During scaffolding, a Backstage
backend action creates a service namespace and provisions an AWS RDS PostgreSQL
resource through Crossplane. On pushes to `main`, the workflow builds an
immutable image in ECR and deploys the service to EKS.

## Run Backstage locally

Requirements: Node.js 22 or 24, Yarn 4, and a GitHub token with permission to
create repositories and write repository contents and workflows.

Set `GITHUB_TOKEN` and `CROSSPLANE_KUBECONFIG` in the environment, and
configure the AWS credential chain for the backend's deployment-role
permissions, then run:

```sh
yarn install
yarn start
```

For PowerShell, set the variables before starting Backstage:

```powershell
$env:GITHUB_TOKEN = "<GitHub token>"
$env:CROSSPLANE_KUBECONFIG = "$HOME\.kube\config"
# Configure AWS credentials with AWS_PROFILE or environment credentials.
yarn start
```

`CROSSPLANE_KUBECONFIG` must point to a kubeconfig available to the Backstage
backend. The backend host needs `kubectl`, AWS CLI v2, and AWS credentials
authorized to create the per-repository deployment roles and EKS access
entries. The same AWS credentials are used by an EKS exec-auth kubeconfig.
Use dedicated AWS and Kubernetes identities; do not use a developer's
cluster-admin kubeconfig in a shared deployment.

Open `http://localhost:3000`, go to **Create**, and select **Node.js Service
with PostgreSQL**. The Backstage GitHub integration uses `GITHUB_TOKEN` to
publish the generated repository. Guest authentication is for local
development only; configure production authentication and authorization before
making this portal available to users.

## Crossplane and AWS prerequisites

Before creating a service:

1. Apply the Terraform dev environment from the repository root as described in
   [`../README.md`](../README.md). It provisions the EKS
   cluster, private database subnets, RDS DB subnet group, database security
   group, GitHub OIDC provider, and ECR repository prefix.
   Configure a self-hosted GitHub Actions runner with the `eks-deployer` label
   on Linux inside the VPC. Terraform creates the runner security group, not
   the runner instance. The EKS endpoint remains restricted; a GitHub-hosted
   runner cannot reach it. Attach the Terraform output
   `github_actions_runner_security_group_id` to the runner instance, and
   install Docker, AWS CLI v2, `kubectl`, and `jq` before registering it with
   GitHub using the `eks-deployer` label.
2. Install Crossplane on the EKS cluster:

   ```sh
   helm repo add crossplane-stable https://charts.crossplane.io/stable
   helm repo update
   helm upgrade --install crossplane crossplane-stable/crossplane \
     --namespace crossplane-system --create-namespace
   ```

3. Configure AWS credentials for Crossplane in the `crossplane-system`
   namespace. The current [`providerconfig-aws.yaml`](./providerconfig-aws.yaml)
   expects a secret named `aws-secret` with key `creds`. Create it from a
   credentials file stored outside the repository, then install the RDS
   provider and ProviderConfig:

   ```sh
   kubectl create secret generic aws-secret \
     --namespace crossplane-system \
     --from-file=creds=<path-to-aws-credentials-file> \
     --dry-run=client --output=yaml | kubectl apply -f -
   kubectl apply -f crossplane/providers/provider-aws-rds.yaml
   kubectl wait --for=condition=Healthy \
     provider.pkg.crossplane.io/provider-aws-rds --timeout=10m
   kubectl apply -f providerconfig-aws.yaml
   ```

   Use an AWS identity limited to the required RDS operations. Never commit the
   credentials file or put credentials in Terraform variables/state.

4. Configure the Backstage backend AWS identity with `sts:GetCallerIdentity`,
   `eks:DescribeCluster`, `eks:DescribeAccessEntry`, `eks:CreateAccessEntry`,
   `eks:UpdateAccessEntry`, `iam:GetRole`, `iam:CreateRole`,
   `iam:UpdateAssumeRolePolicy`, and `iam:PutRolePolicy`. Restrict role
   management to the service deployment-role naming pattern and EKS access
   entry operations to this cluster. Its Kubernetes identity needs
   get/create on Namespaces, get/create/patch on namespace-scoped Roles
   and RoleBindings, get/list/watch/create Secrets, get/create/delete the
   deployment-readiness ConfigMap, and get/list/watch/create/update/patch RDS
   `Instance` resources at cluster scope. The template creates a namespace
   owned by one GitHub repository and a repository-specific deployment role
   and Kubernetes group per service. Choose a unique service name; scaffolding
   rejects a namespace claimed by a different repository. The
   generated database password is sent directly to the Kubernetes API and is
   never placed in the GitHub repository or GitHub Actions secrets.
5. From the Terraform repository root, copy these outputs into the matching
   template fields:

   ```sh
   terraform -chdir=environments/dev output -raw database_subnet_group_name
   terraform -chdir=environments/dev output -raw database_security_group_id
   terraform -chdir=environments/dev output -raw cluster_name
   terraform -chdir=environments/dev output -raw github_actions_oidc_provider_arn
   terraform -chdir=environments/dev output -raw ecr_repository_prefix
   terraform -chdir=environments/dev output -raw aws_region
   terraform -chdir=environments/dev output -raw aws_account_id
   terraform -chdir=environments/dev output -raw github_owner
   ```

   The template's AWS region must match the Terraform environment. The GitHub
   owner configured in Terraform must own the generated repository, and the
   per-repository deployment role trusts only pushes to that repository's
   `main` branch.

The Backstage action creates a random password Secret once and preserves it on
retries. It creates a namespace, a Role and RoleBinding limited to deploying
the service's Deployment and Service, then creates a repository-specific IAM
role and EKS access entry. It applies the RDS manifest after publishing the
repository and waits up to 45 minutes for Crossplane to report the instance
ready and for the connection Secret to exist. It then writes a
deployment-readiness ConfigMap so the initial GitHub workflow cannot race
database provisioning. Crossplane writes the connection details to a separate
`<service>-db-connection` Secret in that namespace. Restrict access to both
Secrets. The RDS instance is private and encrypted at rest.

If provisioning fails after the repository is published, fix the reported
Crossplane or AWS issue and re-apply the manifest from that repository:

```sh
kubectl apply -f infra/rds-instance.yaml
kubectl wait --for=condition=Ready --timeout=45m -f infra/rds-instance.yaml
```

The backend Dockerfile installs `kubectl` v1.31.0 and AWS CLI v2; override the
`KUBECTL_VERSION` build argument to match the EKS cluster's supported client
version when building for production.

## Generated service

The generated repository includes a Node.js health endpoint and tests, a
Dockerfile, a catalog descriptor, the Crossplane RDS manifest at
`infra/rds-instance.yaml`, EKS Deployment and Service manifests under `k8s/`,
and the CI/CD workflow at `.github/workflows/ci.yml`. CI runs on GitHub-hosted
runners; deployment runs on the self-hosted `eks-deployer` runner in the VPC.
The workflow creates a per-service ECR repository with immutable image tags
and retains the latest 30 images. The Kubernetes Service is `ClusterIP` and
requires an ingress or other routing configuration for external access.
Service teardown is not automated: remove its EKS access entry, per-repository
IAM role, ECR repository, namespace, and database after reviewing retention
requirements. Database deletion uses AWS's final snapshot behavior; review the
snapshot and retention policy before changing the resource's lifecycle.
