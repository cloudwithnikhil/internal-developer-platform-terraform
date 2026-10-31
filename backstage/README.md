# Internal Developer Portal

This Backstage app includes a **Node.js Service with PostgreSQL** software
template. The template creates a GitHub repository containing a tested Node.js
service and GitHub Actions CI workflow. During scaffolding, a Backstage backend
action provisions an AWS RDS PostgreSQL resource through Crossplane and waits
for it to be ready.

## Run Backstage locally

Requirements: Node.js 22 or 24, Yarn 4, and a GitHub token with permission to
create repositories and write repository contents and workflows.

Set `GITHUB_TOKEN` and `CROSSPLANE_KUBECONFIG` in the environment, then run:

```sh
yarn install
yarn start
```

For PowerShell, set the variables before starting Backstage:

```powershell
$env:GITHUB_TOKEN = "<GitHub token>"
$env:CROSSPLANE_KUBECONFIG = "$HOME\.kube\config"
yarn start
```

`CROSSPLANE_KUBECONFIG` must point to a kubeconfig available to the Backstage
backend. The backend host also needs `kubectl` and AWS credentials if the
kubeconfig uses the EKS exec authentication plugin. Use a dedicated Kubernetes
identity with only the permissions described below; do not use a developer's
cluster-admin kubeconfig in a shared deployment.

Open `http://localhost:3000`, go to **Create**, and select **Node.js Service
with PostgreSQL**. The Backstage GitHub integration uses `GITHUB_TOKEN` to
publish the generated repository. Guest authentication is for local
development only; configure production authentication and authorization before
making this portal available to users.

## Crossplane and AWS prerequisites

Before creating a service:

1. Apply the Terraform dev environment from the repository root as described in
   [`../README.md`](../README.md). It provisions the EKS cluster, private
   database subnets, RDS DB subnet group, and database security group.
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

4. Configure the Backstage backend identity to get/create Secrets in the
   selected namespace and get/list/watch/create/update/patch RDS `Instance`
   resources at cluster scope. The namespace must already exist. The generated
   database password is sent directly to the Kubernetes API and is never placed
   in the GitHub repository or GitHub Actions secrets.
5. From the Terraform repository root, copy these outputs into the matching
   template fields:

   ```sh
   terraform -chdir=environments/dev output -raw database_subnet_group_name
   terraform -chdir=environments/dev output -raw database_security_group_id
   ```

The Backstage action creates a random password Secret once and preserves it on
retries. It applies the RDS manifest after publishing the repository and waits
up to 45 minutes for Crossplane to report the instance ready. Crossplane writes
the connection details to a separate `<service>-db-connection` Secret in the
selected namespace. Restrict access to both Secrets. The RDS instance is
private and encrypted at rest.

If provisioning fails after the repository is published, fix the reported
Crossplane or AWS issue and re-apply the manifest from that repository:

```sh
kubectl apply -f infra/rds-instance.yaml
kubectl wait --for=condition=Ready --timeout=45m -f infra/rds-instance.yaml
```

The backend Dockerfile installs `kubectl` v1.31.0; override the
`KUBECTL_VERSION` build argument to match the EKS cluster's supported client
version when building for production.

## Generated service

The generated repository includes a Node.js health endpoint and tests, a
Dockerfile, a catalog descriptor, the Crossplane RDS manifest at
`infra/rds-instance.yaml`, and the CI/CD workflow at
`.github/workflows/ci.yml`. Database deletion uses AWS's final snapshot
behavior; review the snapshot and retention policy before changing the
resource's lifecycle.
