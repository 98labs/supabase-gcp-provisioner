# Architecture Overview

## System Architecture

The Supabase deployment on GCP follows a serverless microservices architecture with the following components:

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │
┌────────▼────────┐
│ Cloud Load      │ (Optional)
│ Balancer + SSL  │
└────────┬────────┘
         │
┌────────▼────────┐
│ Google Cloud    │
│ API Gateway     │
└────────┬────────┘
         │
┌────────┴────────┐
│   Cloud Run     │
│   Services      │
├─────────────────┤
│ • Auth          │
│ • REST          │
│ • Storage       │
│ • Meta          │
│ • Realtime      │
│ • Studio        │
│ • Functions     │
└────────┬────────┘
         │
┌────────▼────────┐
│  Cloud SQL/     │
│   AlloyDB       │
└─────────────────┘
```

## Component Details

### 1. API Gateway Layer
- **Google Cloud API Gateway**
  - Fully managed API gateway service
  - OpenAPI specification-based routing
  - Built-in authentication and authorization
  - Automatic scaling and high availability
  - Request/response transformation
  - Rate limiting and quota management

### 2. Load Balancer Layer (Optional)
- **Google Cloud Global External Application Load Balancer**
  - Required only for custom domain setup
  - Provides global anycast IP
  - Automatic SSL certificate management
  - Cloud Armor DDoS protection
  - Routes all traffic to API Gateway

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

- **Realtime**
  - WebSocket connections for real-time features
  - PostgreSQL CDC (Change Data Capture)
  - Presence and broadcast features
  - Deployed on Cloud Run with WebSocket support

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
└── VPC Connector: 10.1.0.0/28
```

### Security Zones
1. **Public Zone**
   - API Gateway endpoint
   - Optional Load Balancer
   - Cloud Armor rules

2. **Application Zone**
   - Cloud Run services
   - VPC connector for private access
   - Service-to-service authentication

3. **Data Zone**
   - Cloud SQL/AlloyDB
   - Cloud Storage
   - Private service connection

## Security Architecture

### Authentication Flow
```
Client → API Gateway → Cloud Run Service
  ↓                           ↓
  └─── API Key/JWT ──────────┘
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
- **Cloud Run**: Automatic scaling based on requests (0 to 1000 instances)
- **API Gateway**: Automatic scaling, no configuration needed
- **Database**: Read replicas for scaling reads

### Vertical Scaling
- **Cloud Run**: Up to 32GB RAM, 8 vCPUs per instance
- **Database**: Resize instances with minimal downtime

## High Availability

### Multi-Zone Deployment
- Cloud Run services automatically deployed across zones
- Cloud SQL regional configuration
- API Gateway multi-region support

### Failover Strategy
- Automatic failover for database
- Cloud Run automatic instance replacement
- API Gateway automatic rerouting

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