#!/bin/bash
set -euo pipefail

# Script to update Kubernetes secrets from Terraform outputs

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get cluster credentials
print_status "Getting GKE credentials..."
eval $(terraform -chdir=terraform output -raw connect_to_gke)

# Get values from Terraform
print_status "Getting values from Terraform outputs..."
ANON_KEY=$(terraform -chdir=terraform output -raw supabase_anon_key)
SERVICE_ROLE_KEY=$(terraform -chdir=terraform output -raw supabase_service_role_key)
JWT_SECRET=$(terraform -chdir=terraform output -raw jwt_secret)
DB_HOST=$(terraform -chdir=terraform output -raw database_host)
DB_PASSWORD=$(terraform -chdir=terraform output -raw database_password)

# Update secrets
print_status "Updating Kubernetes secrets..."

kubectl create secret generic supabase-keys \
    --namespace=supabase \
    --from-literal=anon-key="$ANON_KEY" \
    --from-literal=service-role-key="$SERVICE_ROLE_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic supabase-jwt \
    --namespace=supabase \
    --from-literal=secret="$JWT_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic supabase-db \
    --namespace=supabase \
    --from-literal=host="$DB_HOST" \
    --from-literal=password="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Restart deployments to pick up new secrets
print_status "Restarting deployments..."
kubectl rollout restart deployment -n supabase

print_status "Secrets updated successfully!"