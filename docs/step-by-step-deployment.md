# Step-by-Step Deployment Guide

This guide walks you through deploying Supabase on Google Cloud Platform.

## Prerequisites

1. **Google Cloud Account**
   - Active GCP project with billing enabled
   - Owner or Editor role on the project

2. **Local Tools**
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
   - [Terraform](https://www.terraform.io/downloads) >= 1.0
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - [Docker](https://docs.docker.com/get-docker/)
   - Git

3. **Domain Name** (optional but recommended)
   - A domain you control for SSL certificates
   - Access to DNS management

## Step 1: Initial Setup

### 1.1 Clone the Repository
```bash
git clone <your-repo-url>
cd gcp-provisioner
```

### 1.2 Authenticate with Google Cloud
```bash
gcloud auth login
gcloud auth application-default login
```

### 1.3 Set Your Project
```bash
gcloud config set project YOUR_PROJECT_ID
```

## Step 2: Configure Terraform Variables

### 2.1 Copy the Example Variables File
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### 2.2 Generate Required Keys

Generate JWT secret (minimum 32 characters):
```bash
openssl rand -base64 32
```

Generate anon and service role keys using the Supabase CLI or online tool:
- Visit [Supabase JWT Generator](https://supabase.com/docs/guides/auth/jwts)
- Or use the Supabase CLI: `supabase keys generate`

### 2.3 Edit terraform.tfvars

Open `terraform/terraform.tfvars` and fill in all required values:

```hcl
# GCP Configuration
project_id   = "your-gcp-project-id"
region       = "us-central1"  # Choose your preferred region

# Supabase Configuration
jwt_secret       = "your-generated-jwt-secret"
anon_key         = "your-anon-key"
service_role_key = "your-service-role-key"

# Domain Configuration
domain = "api.yourdomain.com"  # Your domain for Supabase

# Dashboard Configuration
dashboard_username = "admin"
dashboard_password = "secure-password-here"

# Optional: SMTP Configuration for emails
smtp_host       = "smtp.sendgrid.net"
smtp_user       = "apikey"
smtp_password   = "your-sendgrid-api-key"
smtp_from_email = "noreply@yourdomain.com"
```

## Step 3: Deploy Infrastructure

### 3.1 Run the Deployment Script
```bash
./scripts/deploy.sh
```

This script will:
1. Validate prerequisites
2. Initialize and apply Terraform
3. Build and push Docker images
4. Deploy Kubernetes resources
5. Configure secrets

### 3.2 Monitor the Deployment

Watch Terraform progress:
```bash
# In the terraform directory
terraform plan
terraform apply
```

Monitor Kubernetes deployments:
```bash
kubectl get pods -n supabase -w
```

## Step 4: Configure DNS

### 4.1 Get the Load Balancer IP
```bash
terraform -chdir=terraform output load_balancer_ip_address
```

### 4.2 Update DNS Records

Add an A record pointing your domain to the load balancer IP:
```
Type: A
Name: api (or your subdomain)
Value: <LOAD_BALANCER_IP>
TTL: 300
```

### 4.3 Wait for SSL Certificate

The managed SSL certificate can take up to 15 minutes to provision. Check status:
```bash
gcloud compute ssl-certificates describe supabase-ssl-cert --global
```

## Step 5: Initialize Database

### 5.1 Connect to Database
```bash
# Get connection details
terraform -chdir=terraform output database_host
terraform -chdir=terraform output -raw database_password

# Connect using Cloud SQL Proxy or from a GCE instance
psql -h <DATABASE_HOST> -U supabase -d supabase
```

### 5.2 Run Initial Setup

Create required extensions:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
```

## Step 6: Verify Deployment

### 6.1 Check Service Health

Test each endpoint:
```bash
# Replace with your domain
DOMAIN="https://api.yourdomain.com"

# Auth service
curl $DOMAIN/auth/v1/health

# REST API
curl $DOMAIN/rest/v1/

# Storage
curl $DOMAIN/storage/v1/version

# Realtime
curl $DOMAIN/realtime/v1/
```

### 6.2 Access Monitoring

View the monitoring dashboard:
```bash
terraform -chdir=terraform output dashboard_url
```

## Step 7: Post-Deployment Configuration

### 7.1 Configure Storage Buckets

Create default storage buckets:
```bash
# Use the Supabase CLI or API to create buckets
curl -X POST $DOMAIN/storage/v1/bucket \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "avatars", "name": "avatars", "public": true}'
```

### 7.2 Set Up Database Migrations

Configure your migration tool to connect to the database:
```bash
export DATABASE_URL="postgresql://supabase:<password>@<host>:5432/supabase"
```

## Troubleshooting

### Common Issues

1. **SSL Certificate Not Working**
   - Ensure DNS is properly configured
   - Wait up to 15 minutes for provisioning
   - Check certificate status: `gcloud compute ssl-certificates list`

2. **Pods Not Starting**
   - Check logs: `kubectl logs -n supabase <pod-name>`
   - Verify secrets: `kubectl get secrets -n supabase`
   - Check events: `kubectl describe pod -n supabase <pod-name>`

3. **Database Connection Issues**
   - Verify VPC peering is established
   - Check firewall rules
   - Ensure services are in the same region

4. **Load Balancer Not Responding**
   - Check backend health: `gcloud compute backend-services get-health`
   - Verify NEG configuration
   - Check firewall rules for health checks

### Getting Help

- Check logs in Cloud Logging
- Review Terraform state: `terraform show`
- Inspect Kubernetes resources: `kubectl describe -n supabase`

## Next Steps

1. **Enable Additional Features**
   - Configure OAuth providers in Auth service
   - Set up custom SMTP for emails
   - Enable additional PostgreSQL extensions

2. **Security Hardening**
   - Review and tighten Cloud Armor rules
   - Configure VPC Service Controls
   - Enable Cloud Security Command Center

3. **Performance Optimization**
   - Configure autoscaling policies
   - Set up Cloud CDN for static assets
   - Optimize database configuration

4. **Backup and Disaster Recovery**
   - Configure automated database backups
   - Set up cross-region replication
   - Document recovery procedures