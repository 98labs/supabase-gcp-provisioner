# Configuration Guide

## Environment Variables

This guide details all configuration options for the Supabase GCP deployment.

## Terraform Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP Project ID | `my-project-123` |
| `jwt_secret` | JWT signing secret (min 32 chars) | `your-super-secret-jwt-key` |
| `anon_key` | Public anonymous key | `eyJhbGc...` |
| `service_role_key` | Service role key with elevated privileges | `eyJhbGc...` |
| `domain` | Domain for your Supabase instance | `api.example.com` |
| `dashboard_password` | Password for Supabase dashboard | `SecurePass123!` |

### Optional Variables

#### Database Configuration
```hcl
database_type              = "cloudsql"    # or "alloydb"
database_version           = "POSTGRES_15"
database_tier              = "db-custom-4-16384"
database_disk_size         = 100
database_availability_type = "REGIONAL"    # or "ZONAL"
```

#### Network Configuration
```hcl
region            = "us-central1"
zone              = "us-central1-a"
subnet_cidr       = "10.0.0.0/20"
gke_pods_cidr     = "10.0.16.0/20"
gke_services_cidr = "10.0.32.0/20"
```

#### GKE Configuration
```hcl
gke_node_count        = 3
gke_node_machine_type = "n2-standard-4"
gke_node_disk_size    = 100
```

#### SMTP Configuration
```hcl
smtp_host       = "smtp.sendgrid.net"
smtp_port       = 587
smtp_user       = "apikey"
smtp_password   = "SG.xxxxx"
smtp_from_email = "noreply@example.com"
```

#### Feature Flags
```hcl
enable_monitoring   = true
enable_logging      = true
enable_cloud_armor  = true
enable_custom_domain = true
```

## Service-Specific Configuration

### Auth Service (GoTrue)

Environment variables for the Auth service:

```yaml
GOTRUE_SITE_URL: https://example.com
GOTRUE_URI_ALLOW_LIST: https://example.com,https://app.example.com
GOTRUE_DISABLE_SIGNUP: false
GOTRUE_EXTERNAL_EMAIL_ENABLED: true
GOTRUE_MAILER_AUTOCONFIRM: false
GOTRUE_SMS_AUTOCONFIRM: true
GOTRUE_EXTERNAL_PHONE_ENABLED: true
GOTRUE_SMS_PROVIDER: twilio  # or messagebird, textlocal
```

OAuth Provider Configuration:
```yaml
# Google OAuth
GOTRUE_EXTERNAL_GOOGLE_ENABLED: true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: your-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET: your-client-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: https://api.example.com/auth/v1/callback

# GitHub OAuth
GOTRUE_EXTERNAL_GITHUB_ENABLED: true
GOTRUE_EXTERNAL_GITHUB_CLIENT_ID: your-client-id
GOTRUE_EXTERNAL_GITHUB_SECRET: your-client-secret
```

### PostgREST Configuration

```yaml
PGRST_DB_SCHEMA: public,storage,graphql_public
PGRST_DB_ANON_ROLE: anon
PGRST_DB_MAX_ROWS: 1000
PGRST_DB_EXTRA_SEARCH_PATH: public,extensions
PGRST_MAX_ROWS: 1000
PGRST_PRE_REQUEST: public.pre_request
```

### Storage API Configuration

```yaml
STORAGE_BACKEND: gcs  # Google Cloud Storage
GCS_BUCKET: project-id-supabase-storage
FILE_SIZE_LIMIT: 52428800  # 50MB
STORAGE_FILE_PATH: /var/lib/storage
ENABLE_IMAGE_TRANSFORMATION: true
IMGPROXY_URL: http://imgproxy:5001
```

### Realtime Configuration

```yaml
DB_POOL_SIZE: 10
DB_QUEUE_TARGET: 50
DB_QUEUE_INTERVAL: 1000
REPLICATION_MODE: RLS  # or STREAM
REPLICATION_POLL_INTERVAL: 100
SECURE_CHANNELS: true
SLOT_NAME: supabase_realtime_rls
MAX_RECORD_BYTES: 1048576
```

## Database Extensions

Required PostgreSQL extensions:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgaudit";
CREATE EXTENSION IF NOT EXISTS "plpgsql";
CREATE EXTENSION IF NOT EXISTS "plpgsql_check";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "pgsodium";
CREATE EXTENSION IF NOT EXISTS "pg_graphql";
CREATE EXTENSION IF NOT EXISTS "pg_jsonschema";
```

## Kong API Gateway Routes

### Default Routes Configuration

```yaml
/auth/v1/*    → Auth Service (Port 9999)
/rest/v1/*    → PostgREST (Port 3000)
/realtime/v1/* → Realtime (Port 4000)
/storage/v1/*  → Storage API (Port 5000)
/pg/*         → Postgres Meta (Port 8080)
/graphql/v1/* → GraphQL (Port 8080)
```

### Rate Limiting Configuration

```yaml
auth:
  rate_limit: 100/minute
  burst: 20

rest:
  rate_limit: 1000/minute
  burst: 100

storage:
  rate_limit: 100/minute
  burst: 20
```

## Monitoring Configuration

### Alert Thresholds

```yaml
cpu_utilization: 80%
memory_utilization: 85%
database_connections: 150
error_rate: 5%
response_time_p99: 1000ms
```

### Log Retention

```yaml
application_logs: 30 days
access_logs: 90 days
audit_logs: 365 days
```

## Security Configuration

### Cloud Armor Rules

```yaml
# Rate limiting
rate_limit:
  threshold: 100
  interval: 60s
  action: throttle

# SQL injection protection
sqli_protection:
  sensitivity: NORMAL
  action: deny(403)

# XSS protection
xss_protection:
  sensitivity: NORMAL
  action: deny(403)

# Geographic restrictions (optional)
geo_restrictions:
  allowed_regions: ["US", "EU", "AS"]
  action: deny(403)
```

### Network Security

```yaml
# Firewall rules
allowed_ingress:
  - 0.0.0.0/0:443  # HTTPS
  - 0.0.0.0/0:80   # HTTP (redirects to HTTPS)

internal_only:
  - database: 10.0.0.0/20
  - storage: 10.0.0.0/20
```

## Performance Tuning

### Database Performance

```sql
-- Connection pooling
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

-- Write performance
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
```

### Application Performance

```yaml
# Cloud Run
min_instances: 1
max_instances: 100
cpu_limit: 2
memory_limit: 2Gi
timeout: 300s

# GKE
autoscaling:
  min_replicas: 2
  max_replicas: 10
  target_cpu: 70%
  target_memory: 80%
```

## Backup Configuration

```yaml
# Database backups
backup:
  enabled: true
  schedule: "0 2 * * *"  # 2 AM daily
  retention_days: 30
  point_in_time_recovery: true

# Storage backups
storage:
  versioning: true
  lifecycle:
    delete_after_days: 90
    archive_after_days: 30
```