# Architecture Overview

## System Architecture

The Supabase deployment on GCP follows a microservices architecture with the following components:

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │
┌────────▼────────┐
│ Cloud Load      │
│ Balancer + SSL  │
└────────┬────────┘
         │
┌────────▼────────┐
│  Kong Gateway   │ (GKE)
│   (Router)      │
└───┬─────────┬───┘
    │         │
┌───▼───┐ ┌───▼───┐
│Cloud  │ │  GKE  │
│ Run   │ │       │
├───────┤ ├───────┤
│ Auth  │ │Real-  │
│ REST  │ │ time  │
│Storage│ └───────┘
│ Meta  │
└───┬───┘
    │
┌───▼───────────┐
│  Cloud SQL/   │
│   AlloyDB     │
└───────────────┘
```

## Component Details

### 1. Load Balancer Layer
- **Google Cloud Global External Application Load Balancer**
  - Provides global anycast IP
  - Automatic SSL certificate management
  - Cloud Armor DDoS protection
  - URL-based routing to backends

### 2. API Gateway (Kong)
- **Deployed on GKE**
  - Handles authentication via API keys
  - Routes requests to appropriate services
  - Applies rate limiting and CORS policies
  - Manages service discovery

### 3. Application Services

#### Cloud Run Services
- **Auth Service (GoTrue)**
  - JWT-based authentication
  - Social OAuth providers
  - Email/SMS authentication
  - User management

- **REST API (PostgREST)**
  - Auto-generated REST API from PostgreSQL schema
  - Row Level Security enforcement
  - Real-time subscriptions support

- **Storage API**
  - S3-compatible object storage
  - Integrates with Google Cloud Storage
  - Image transformation capabilities
  - Access control via PostgreSQL RLS

- **Postgres Meta**
  - Database introspection API
  - Schema management
  - Table and column metadata

#### GKE Services
- **Realtime**
  - WebSocket connections for real-time features
  - PostgreSQL CDC (Change Data Capture)
  - Presence and broadcast features
  - Horizontal scaling with multiple pods

### 4. Database Layer
- **Cloud SQL or AlloyDB**
  - PostgreSQL 15+ with extensions
  - Private VPC connectivity
  - Automated backups and point-in-time recovery
  - High availability with regional replicas

### 5. Storage Layer
- **Google Cloud Storage**
  - Object storage for user uploads
  - KMS encryption at rest
  - Versioning and lifecycle policies
  - CDN integration for performance

## Network Architecture

### VPC Design
```
VPC: 10.0.0.0/16
├── Main Subnet: 10.0.0.0/20
├── GKE Pods: 10.0.16.0/20
├── GKE Services: 10.0.32.0/20
└── VPC Connector: 10.1.0.0/28
```

### Security Zones
1. **Public Zone**
   - Load Balancer
   - Cloud Armor rules

2. **Application Zone**
   - Cloud Run services
   - GKE cluster
   - VPC connector for private access

3. **Data Zone**
   - Cloud SQL/AlloyDB
   - Cloud Storage
   - Private service connection

## Security Architecture

### Authentication Flow
```
Client → Load Balancer → Kong → Service
  ↓                               ↓
  └─── API Key (anon/service) ───┘
                                  ↓
                          JWT Validation
                                  ↓
                          Database (RLS)
```

### Security Layers
1. **Network Security**
   - Cloud Armor for DDoS protection
   - VPC firewall rules
   - Private Google Access

2. **Application Security**
   - JWT authentication
   - API key validation
   - Service accounts with least privilege

3. **Data Security**
   - Encryption at rest (KMS)
   - Encryption in transit (TLS)
   - Row Level Security in PostgreSQL

## Scalability Design

### Horizontal Scaling
- **Cloud Run**: Automatic scaling based on requests
- **GKE**: HPA (Horizontal Pod Autoscaler) for Realtime
- **Database**: Read replicas for scaling reads

### Vertical Scaling
- **Cloud Run**: Up to 32GB RAM, 8 vCPUs per instance
- **GKE**: Node pools with different machine types
- **Database**: Resize instances with minimal downtime

## High Availability

### Multi-Zone Deployment
- GKE cluster spans multiple zones
- Cloud SQL regional configuration
- Cloud Run services in multiple zones

### Failover Strategy
- Automatic failover for database
- Load balancer health checks
- Kubernetes self-healing

## Monitoring and Observability

### Metrics Collection
- Cloud Monitoring for all GCP services
- Custom metrics from applications
- Database performance insights

### Logging
- Centralized logging in Cloud Logging
- Log aggregation to Cloud Storage
- Structured logging from applications

### Alerting
- Uptime checks for endpoints
- Resource utilization alerts
- Custom alert policies

## Cost Optimization

### Resource Optimization
- Preemptible nodes for non-critical workloads
- Autoscaling to match demand
- Committed use discounts

### Storage Optimization
- Lifecycle policies for old data
- Nearline storage for logs
- CDN caching for static assets