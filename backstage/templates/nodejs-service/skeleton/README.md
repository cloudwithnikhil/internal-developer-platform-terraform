# Node.js Service

A Node.js service generated using Backstage Software Templates.

## Requirements

- Node.js 22 or later
- Docker (optional)

## Run locally

    npm install
    npm start

## Health check

    curl http://localhost:3000/health

## Run tests

    npm test

## Build Docker image

    docker build -t nodejs-service .

## Run Docker container

    docker run -p 3000:3000 nodejs-service

## Managed PostgreSQL database

Backstage provisions a private PostgreSQL RDS instance through Crossplane when
this repository is scaffolded. The database connection details are written to
the `<service-name>-db-connection` Secret in this service's Kubernetes
namespace. The deployment injects the endpoint, port, username, and password
as `PGHOST`, `PGPORT`, `PGUSER`, and `PGPASSWORD`; the generated application
must use a PostgreSQL client to connect. The database password is stored
separately in `<service-name>-db-credentials`. Do not print secret values in
CI logs.

## CI/CD deployment

The GitHub Actions workflow tests pull requests and pushes. Pushes to `main`
also build and publish an immutable image to ECR and update the EKS Deployment.
The deployment job requires a self-hosted runner labeled `eks-deployer` inside
the AWS VPC, with Docker, AWS CLI v2, `kubectl`, and `jq` installed. The
Kubernetes Service is internal (`ClusterIP`); configure ingress or routing
separately if the service needs external access.
