#!/bin/bash
set -euo pipefail

# Script to build and deploy Studio separately

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_error "terraform not found. Please install Terraform."
        exit 1
    fi
}

# Build Studio image
build_studio() {
    print_status "Building Studio image..."
    
    # Get registry URL from Terraform
    if ! REGISTRY=$(terraform -chdir=terraform output -raw artifact_registry 2>/dev/null); then
        print_error "Could not get artifact registry URL. Have you run terraform apply?"
        exit 1
    fi
    
    # Get domain from terraform vars
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_error "terraform/terraform.tfvars not found!"
        exit 1
    fi
    
    DOMAIN=$(grep "^domain" terraform/terraform.tfvars | cut -d'"' -f2)
    
    # Configure Docker for GCR
    print_status "Configuring Docker authentication..."
    gcloud auth configure-docker "${REGISTRY%%/*}"
    
    # Clone Supabase repo if not exists
    if [ ! -d "supabase" ]; then
        print_status "Cloning Supabase repository..."
        git clone --depth 1 https://github.com/supabase/supabase.git
    else
        print_status "Updating Supabase repository..."
        cd supabase && git pull && cd ..
    fi
    
    # Create temporary config
    print_status "Creating configuration..."
    cp docker/studio/config.json docker/studio/config.json.tmp
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" docker/studio/config.json.tmp
    
    # Build image
    print_status "Building Docker image..."
    docker build \
        --build-arg DOMAIN="$DOMAIN" \
        -t "$REGISTRY/studio:latest" \
        -f docker/studio/Dockerfile \
        .
    
    # Clean up
    rm docker/studio/config.json.tmp
    
    print_status "Studio image built successfully!"
}

# Push Studio image
push_studio() {
    print_status "Pushing Studio image to registry..."
    
    REGISTRY=$(terraform -chdir=terraform output -raw artifact_registry)
    docker push "$REGISTRY/studio:latest"
    
    print_status "Studio image pushed successfully!"
}

# Deploy Studio to Cloud Run
deploy_studio() {
    print_status "Deploying Studio to Cloud Run..."
    
    # Apply just the Studio service
    cd terraform
    terraform apply -target=google_cloud_run_v2_service.services[\"studio\"] -auto-approve
    cd ..
    
    print_status "Studio deployed successfully!"
}

# Get Studio URL
get_studio_url() {
    DOMAIN=$(grep "^domain" terraform/terraform.tfvars | cut -d'"' -f2)
    STUDIO_URL="https://$DOMAIN/console"
    
    print_status "Studio is available at: $STUDIO_URL"
    print_status "Note: It may take a few minutes for the service to be fully available."
}

# Main function
main() {
    print_status "Starting Studio build and deployment..."
    
    check_prerequisites
    build_studio
    push_studio
    deploy_studio
    get_studio_url
    
    print_status "Studio deployment completed!"
}

# Parse command line arguments
case "${1:-all}" in
    build)
        check_prerequisites
        build_studio
        ;;
    push)
        check_prerequisites
        push_studio
        ;;
    deploy)
        check_prerequisites
        deploy_studio
        get_studio_url
        ;;
    all)
        main
        ;;
    *)
        echo "Usage: $0 [build|push|deploy|all]"
        exit 1
        ;;
esac