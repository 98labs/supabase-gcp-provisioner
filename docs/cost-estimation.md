# Cost Estimation Guide

This guide provides estimated monthly costs for running Supabase on Google Cloud Platform. All prices are in USD and based on GCP's pricing as of 2024.

## Cost Summary

### Minimal Setup (Development/Testing)
- **Estimated Monthly Cost**: $150-250
- Single zone deployment
- Minimal resources
- Basic monitoring

### Standard Setup (Small Production)
- **Estimated Monthly Cost**: $500-800
- Regional high availability
- Standard resources
- Full monitoring and backups

### Enterprise Setup (Large Production)
- **Estimated Monthly Cost**: $2000+
- Multi-regional deployment
- High-performance resources
- Advanced security and monitoring

## Detailed Cost Breakdown

### 1. Database (Cloud SQL PostgreSQL)

#### Development Tier
```
Instance: db-f1-micro
vCPUs: Shared (0.6)
Memory: 0.6 GB
Storage: 10 GB SSD
Estimated: $15/month
```

#### Standard Tier
```
Instance: db-custom-4-16384
vCPUs: 4
Memory: 16 GB
Storage: 100 GB SSD
High Availability: Yes
Estimated: $400/month
```

#### Enterprise Tier
```
Instance: db-custom-16-65536
vCPUs: 16
Memory: 64 GB
Storage: 500 GB SSD
High Availability: Yes
Read Replicas: 2
Estimated: $2000/month
```

### 2. Google Kubernetes Engine (GKE)

#### Cluster Management
```
GKE Cluster management fee: $0.10/hour
Monthly: ~$73
```

#### Node Pool Costs
```
Standard Setup (3 nodes):
- Machine type: n2-standard-4
- vCPUs: 4 per node (12 total)
- Memory: 16 GB per node (48 GB total)
- Disk: 100 GB SSD per node
- Estimated: $450/month

With Preemptible Nodes (80% discount):
- Estimated: $90/month
```

### 3. Cloud Run Services

Pricing based on:
- vCPU-seconds: $0.00002400/vCPU-second
- Memory: $0.00000250/GiB-second
- Requests: $0.40/million requests

#### Per Service Estimate (Auth, REST, Storage, Meta, Studio)
```
Standard services (Auth, REST, Storage, Meta):
- Minimum instances: 1
- Maximum instances: 10
- Average usage: 2 instances
- CPU: 1 vCPU
- Memory: 1 GiB
- Per service: ~$50/month

Studio (Dashboard):
- Minimum instances: 1
- Maximum instances: 5
- Average usage: 2 instances
- CPU: 2 vCPU
- Memory: 2 GiB
- Estimated: ~$100/month

Total (5 services): ~$300/month
```

### 4. Load Balancer

```
Forwarding Rules: $0.025/hour each
- HTTP rule: $18/month
- HTTPS rule: $18/month

Data Processing: $0.008/GB
- Estimated 1TB/month: $8

Total: ~$44/month
```

### 5. Storage (Google Cloud Storage)

```
Standard Storage: $0.020/GB/month
Operations: $0.005/10,000 operations
Egress: $0.12/GB (after 1GB free)

Example (100GB storage, 1TB egress):
- Storage: $2
- Operations: ~$5
- Egress: $120
Total: ~$127/month
```

### 6. Networking

#### VPC and Cloud NAT
```
Cloud NAT: $0.045/hour + $0.045/GB processed
- Base cost: $32/month
- Data processing (1TB): $45
Total: ~$77/month
```

#### VPC Connector (for Cloud Run)
```
$0.36/hour for e2-micro instance
Monthly: ~$260
```

### 7. Monitoring and Logging

```
Monitoring:
- First 150 GB logs: Free
- Additional logs: $0.50/GB
- Metrics: $0.258/1000 metrics

Estimated: $50-100/month
```

### 8. Additional Services

#### Cloud Armor (DDoS Protection)
```
Policy: $5/month
Rules: $1/month each
Requests: $0.75/million
Estimated: $20/month
```

#### SSL Certificates
```
Managed certificates: Free
```

#### Secrets Manager
```
Active secrets: $0.06/secret/month
Access operations: $0.03/10,000
Estimated: $5/month
```

## Cost Optimization Strategies

### 1. Use Preemptible VMs
- 60-91% discount on GKE nodes
- Suitable for stateless services
- Not recommended for databases

### 2. Committed Use Discounts
- 1-year commitment: 37% discount
- 3-year commitment: 55% discount
- Available for Compute Engine and Cloud SQL

### 3. Resource Right-Sizing
```bash
# Monitor actual usage
gcloud monitoring metrics list --filter="resource.type=cloud_run_revision"

# Adjust resources based on metrics
terraform apply -var="gke_node_machine_type=n2-standard-2"
```

### 4. Auto-scaling Configuration
```yaml
# Aggressive scaling for cost optimization
autoscaling:
  min_instances: 0  # Scale to zero
  max_instances: 5  # Lower maximum
  target_utilization: 0.8  # Higher threshold
```

### 5. Storage Optimization
- Use lifecycle policies to move old data to Nearline/Coldline
- Enable compression for logs
- Set appropriate retention periods

### 6. Regional vs Multi-Regional
- Regional deployment: Standard pricing
- Multi-regional: 2.5x storage cost
- Choose based on actual requirements

## Monthly Cost Calculator

### Basic Formula
```
Total Monthly Cost = 
  Database Cost +
  (GKE Nodes × Node Cost) +
  (Cloud Run Services × Service Cost) +
  Load Balancer Cost +
  (Storage GB × $0.020) +
  (Egress GB × $0.12) +
  Monitoring Cost +
  Additional Services
```

### Example Calculations

#### Startup (10,000 users)
```
Database (db-custom-2-8192): $150
GKE (2 preemptible nodes): $60
Cloud Run (minimal): $100
Load Balancer: $44
Storage (50GB + 500GB egress): $62
Monitoring: $30
Total: ~$446/month
```

#### Growing Business (100,000 users)
```
Database (db-custom-4-16384 + HA): $400
GKE (3 standard nodes): $450
Cloud Run (moderate): $200
Load Balancer: $44
Storage (500GB + 5TB egress): $610
Monitoring: $100
Total: ~$1,804/month
```

#### Enterprise (1M+ users)
```
Database (db-custom-16-65536 + HA + replicas): $2000
GKE (5 nodes + autoscaling): $750
Cloud Run (high usage): $500
Load Balancer: $44
Storage (5TB + 50TB egress): $6,100
Monitoring: $200
Total: ~$9,594/month
```

## Cost Monitoring

### Set Up Budget Alerts
```bash
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Supabase Monthly Budget" \
  --budget-amount=1000 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100
```

### Monitor Costs
```bash
# View current month costs
gcloud billing accounts describe BILLING_ACCOUNT_ID

# Export billing to BigQuery for analysis
gcloud billing export create \
  --billing-account=BILLING_ACCOUNT_ID \
  --dataset-id=billing_export \
  --table-id=gcp_billing_export
```

## Free Tier Considerations

GCP Free Tier includes:
- 1 f1-micro GCE instance/month
- 30 GB standard persistent disk
- 5 GB Cloud Storage
- 1 GB network egress

Note: Free tier has limitations and may not be suitable for production Supabase deployments.