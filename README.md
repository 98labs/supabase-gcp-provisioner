# Supabase GCP Provisioner

This repository contains Terraform configurations and scripts to deploy the entire Supabase platform on Google Cloud Platform (GCP).

## Architecture Overview

- **Database**: Cloud SQL for PostgreSQL or AlloyDB
- **API Gateway**: Google Cloud API Gateway for intelligent routing
- **Load Balancer**: Optional Google Cloud Load Balancer for custom domains
- **Services**: All services deployed on Cloud Run (fully serverless)
- **Storage**: Google Cloud Storage for object storage
- **Functions**: Cloud Run for Edge Functions

## Prerequisites

1. Google Cloud SDK installed and configured
2. Terraform >= 1.0
3. Docker installed
4. A GCP project with billing enabled

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
├── docker/             # Dockerfiles for services
├── scripts/            # Deployment scripts
├── api-gateway/        # API Gateway OpenAPI specifications
└── docs/              # Additional documentation
```

## Services Deployed

| Service | Deployment Type | Endpoint |
|---------|----------------|----------|
| Auth | Cloud Run | /auth/v1 |
| PostgREST | Cloud Run | /rest/v1 |
| Realtime | Cloud Run | /realtime/v1 |
| Storage | Cloud Run | /storage/v1 |
| Postgres Meta | Cloud Run | /pg |
| Functions | Cloud Run | /functions/v1 |
| GraphQL | Cloud Run | /graphql/v1 |
| Studio (Dashboard) | Cloud Run | /console |
| API Gateway | Google Cloud API Gateway | / |

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