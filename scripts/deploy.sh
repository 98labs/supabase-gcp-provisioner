#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_error "terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_error "docker not found. Please install Docker."
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Validate terraform variables
validate_terraform_vars() {
    print_status "Validating Terraform variables..."
    
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_error "terraform/terraform.tfvars not found!"
        print_error "Please copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill in your values."
        exit 1
    fi
    
    # Check required variables
    local required_vars=("project_id" "jwt_secret" "anon_key" "service_role_key" "domain")
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}" terraform/terraform.tfvars; then
            print_error "Required variable '${var}' not found in terraform.tfvars"
            exit 1
        fi
    done
}

# Set up GCP project
setup_gcp_project() {
    print_status "Setting up GCP project..."
    
    # Get project ID from terraform vars
    PROJECT_ID=$(grep "^project_id" terraform/terraform.tfvars | cut -d'"' -f2)
    
    # Set project
    gcloud config set project "$PROJECT_ID"
    
    # Check if billing is enabled
    if ! gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" | grep -q "True"; then
        print_error "Billing is not enabled for project $PROJECT_ID"
        print_error "Please enable billing at: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
        exit 1
    fi
    
    print_status "GCP project configured: $PROJECT_ID"
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Save outputs
    print_status "Saving Terraform outputs..."
    terraform output -json > ../outputs.json
    
    cd ..
    
    print_status "Terraform deployment completed!"
}

# Build and push Docker images
build_docker_images() {
    print_status "Building and pushing Docker images..."
    
    # Get artifact registry URL
    REGISTRY=$(terraform -chdir=terraform output -raw artifact_registry)
    
    # Configure Docker for GCR
    gcloud auth configure-docker "${REGISTRY%%/*}"
    
    # Build Studio image
    if [ -f "docker/studio/Dockerfile" ]; then
        print_status "Building Studio image..."
        
        # Clone Supabase repo if not exists
        if [ ! -d "supabase" ]; then
            print_status "Cloning Supabase repository..."
            git clone --depth 1 https://github.com/supabase/supabase.git
        fi
        
        # Update config with actual domain
        DOMAIN=$(grep "^domain" terraform/terraform.tfvars | cut -d'"' -f2)
        sed -i.bak "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" docker/studio/config.json
        
        # Build and push Studio
        docker build -t "$REGISTRY/studio:latest" -f docker/studio/Dockerfile .
        docker push "$REGISTRY/studio:latest"
        
        # Restore config
        mv docker/studio/config.json.bak docker/studio/config.json
    fi
    
    # Build other custom images if needed
    if [ -d "docker" ]; then
        for dockerfile in docker/*/Dockerfile; do
            if [ -f "$dockerfile" ] && [ "$(basename $(dirname "$dockerfile"))" != "studio" ]; then
                service_name=$(basename $(dirname "$dockerfile"))
                print_status "Building image for $service_name..."
                docker build -t "$REGISTRY/$service_name:latest" -f "$dockerfile" docker/$service_name/
                docker push "$REGISTRY/$service_name:latest"
            fi
        done
    fi
    
    print_status "Docker images ready!"
}

# Deploy API Gateway
deploy_api_gateway() {
    print_status "API Gateway will be deployed as part of Terraform..."
    print_status "Google API Gateway provides automatic routing to all services"
}

# Initialize database
init_database() {
    print_status "Initializing database..."
    
    # This would typically include:
    # - Running initial migrations
    # - Creating necessary extensions
    # - Setting up initial data
    
    print_warning "Database initialization should be implemented based on your specific requirements"
}

# Print deployment summary
print_summary() {
    print_status "Deployment Summary:"
    echo "====================================="
    
    # Get outputs
    API_GATEWAY_URL=$(terraform -chdir=terraform output -raw api_gateway_endpoint 2>/dev/null || echo "Not available")
    DOMAIN=$(grep "^domain" terraform/terraform.tfvars | cut -d'"' -f2)
    ENABLE_CUSTOM_DOMAIN=$(grep "^enable_custom_domain" terraform/terraform.tfvars | grep -q "true" && echo "true" || echo "false")
    
    if [ "$ENABLE_CUSTOM_DOMAIN" = "true" ]; then
        LOAD_BALANCER_IP=$(terraform -chdir=terraform output -raw load_balancer_ip_address)
        SUPABASE_URL=$(terraform -chdir=terraform output -raw supabase_url)
        echo "Load Balancer IP: $LOAD_BALANCER_IP"
        echo "Supabase URL: $SUPABASE_URL"
        echo ""
        echo "Next Steps:"
        echo "1. Point your domain ($DOMAIN) to: $LOAD_BALANCER_IP"
        echo "2. Wait for SSL certificate to be provisioned (can take up to 15 minutes)"
        echo "3. Access your Supabase instance at: $SUPABASE_URL"
    else
        echo "API Gateway URL: $API_GATEWAY_URL"
        echo ""
        echo "Access your Supabase instance at: $API_GATEWAY_URL"
    fi
    
    echo ""
    echo "Studio Dashboard: ${API_GATEWAY_URL}/console"
    echo ""
    echo "To view all outputs including sensitive values:"
    echo "  cd terraform && terraform output"
    echo ""
    echo "API Endpoints:"
    echo "  - Auth: /auth/v1/"
    echo "  - REST: /rest/v1/"
    echo "  - Storage: /storage/v1/"
    echo "  - Realtime: /realtime/v1/"
    echo "  - GraphQL: /graphql/v1"
    echo "====================================="
}

# Main deployment flow
main() {
    print_status "Starting Supabase GCP deployment..."
    
    check_prerequisites
    validate_terraform_vars
    setup_gcp_project
    deploy_terraform
    build_docker_images
    deploy_api_gateway
    init_database
    print_summary
    
    print_status "Deployment completed successfully!"
}

# Run main function
main "$@"