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
the `<service-name>-db-connection` Secret in the selected Kubernetes
namespace. The generated database password is stored separately in
`<service-name>-db-credentials`. Restrict access to both Secrets and do not
print their values in CI logs.
