# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Commands

### Deployment Commands
- `./scripts/deploy.sh` - Full deployment of Supabase on GCP
- `./scripts/destroy.sh` - Destroy all infrastructure (requires confirmation)
- `./scripts/generate-keys.sh` - Generate JWT secret and auth keys

### Terraform Commands
- `cd terraform && terraform plan` - Preview infrastructure changes
- `cd terraform && terraform apply` - Apply infrastructure changes
- `cd terraform && terraform destroy` - Destroy infrastructure
- `cd terraform && terraform output` - View deployment outputs

### Configuration Setup
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
- Run `./scripts/generate-keys.sh` to generate required authentication keys

## Architecture Overview

This repository deploys a complete Supabase platform on Google Cloud Platform using a serverless microservices architecture:

### Core Infrastructure Pattern
- **API Gateway**: Google Cloud API Gateway handles all routing via OpenAPI specifications
- **Services**: All Supabase services run on Cloud Run (Auth, REST, Storage, Realtime, etc.)
- **Database**: Cloud SQL PostgreSQL or AlloyDB with private VPC connectivity
- **Load Balancer**: Optional HTTPS load balancer for custom domains

### Key Terraform Modules
- `main.tf` - Core infrastructure (VPC, service accounts, APIs)
- `cloud-run.tf` - All Supabase microservices deployment
- `database.tf` - Cloud SQL/AlloyDB configuration
- `api-gateway.tf` - API Gateway with OpenAPI routing
- `load-balancer.tf` - Optional external load balancer
- `storage.tf` - Google Cloud Storage buckets
- `monitoring.tf` - Cloud Monitoring and alerting

### Configuration Pattern
The deployment supports two main modes:
1. **API Gateway only**: Direct access via Gateway endpoint
2. **Custom domain**: Load balancer + SSL + custom domain pointing to API Gateway

### Security Model
- Services communicate via private VPC
- Authentication via JWT tokens and service accounts
- Database uses private service connection
- Secrets managed via Google Secret Manager

### Critical Variables in terraform.tfvars
- `project_id` - GCP project
- `jwt_secret` - JWT signing key (generate with scripts/generate-keys.sh)
- `anon_key` - Public API key
- `service_role_key` - Admin API key
- `domain` - Custom domain (if using load balancer)

## Docker Images
Custom images are built for:
- Studio dashboard (`docker/studio/`)
- Functions runtime (`docker/functions/`)
- GraphQL service (`docker/pg_graphql/`)

The `deploy.sh` script automatically builds and pushes these to Google Artifact Registry.

## API Routing
All services are accessed through paths on the main domain:
- `/auth/v1/` - Authentication service
- `/rest/v1/` - PostgREST API
- `/storage/v1/` - Storage service
- `/realtime/v1/` - WebSocket realtime
- `/console` - Studio dashboard
- `/graphql/v1` - GraphQL endpoint