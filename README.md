# Supabase GCP Provisioner

This repository contains Terraform configurations and scripts to deploy the entire Supabase platform on Google Cloud Platform (GCP).

## Architecture Overview

- **Database**: Cloud SQL for PostgreSQL or AlloyDB
- **Load Balancer**: Google Cloud Global External Application Load Balancer
- **API Gateway**: Google Cloud API Gateway for routing
- **Services**: Mix of Cloud Run and GKE deployments
- **Storage**: Google Cloud Storage for object storage
- **Functions**: Cloud Run for Edge Functions

## Prerequisites

1. Google Cloud SDK installed and configured
2. Terraform >= 1.0
3. Docker installed
4. kubectl (for GKE deployments)
5. A GCP project with billing enabled

## Quick Start

1. Clone this repository
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
3. Update the variables in `terraform.tfvars`
4. Run the deployment:
   ```bash
   ./scripts/deploy.sh
   ```

## Directory Structure

```
gcp-provisioner/
├── terraform/           # Terraform configurations
├── k8s/                # Kubernetes manifests
├── docker/             # Dockerfiles for services
├── scripts/            # Deployment scripts
├── api-gateway/        # API Gateway configurations
└── docs/              # Additional documentation
```

## Services Deployed

| Service | Deployment Type | Endpoint |
|---------|----------------|----------|
| Auth | Cloud Run | /auth |
| PostgREST | Cloud Run | /rest |
| Realtime | GKE | /realtime |
| Storage | Cloud Run | /storage |
| Postgres Meta | Cloud Run | /pg |
| Functions | Cloud Run | /functions |
| GraphQL | Cloud Run | /graphql |
| Kong (API Gateway) | GKE | / |

## Configuration

See `docs/configuration.md` for detailed configuration options.

## Monitoring

The deployment includes:
- Cloud Monitoring dashboards
- Log aggregation in Cloud Logging
- Alerts for critical services

## Security

- All services use Google Cloud IAM for authentication
- Secrets stored in Google Secret Manager
- VPC networking with private service connections
- Cloud Armor for DDoS protection

## Cost Estimation

See `docs/cost-estimation.md` for estimated monthly costs based on usage.