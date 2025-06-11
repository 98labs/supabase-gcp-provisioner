#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Confirm destruction
confirm_destroy() {
    print_warning "This will destroy all Supabase resources on GCP!"
    print_warning "This action cannot be undone."
    echo ""
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
    echo
    if [[ ! $REPLY =~ ^yes$ ]]; then
        print_status "Destruction cancelled."
        exit 0
    fi
}

# Delete Kubernetes resources
delete_kubernetes() {
    print_status "Deleting Kubernetes resources..."
    
    # Get cluster credentials if possible
    if terraform -chdir=terraform output -raw connect_to_gke 2>/dev/null; then
        eval $(terraform -chdir=terraform output -raw connect_to_gke)
        
        # Delete resources
        kubectl delete -f k8s/ --ignore-not-found=true || true
        
        # Delete namespace
        kubectl delete namespace supabase --ignore-not-found=true || true
    else
        print_warning "Could not connect to GKE cluster, it may already be deleted"
    fi
}

# Destroy Terraform resources
destroy_terraform() {
    print_status "Destroying Terraform resources..."
    
    cd terraform
    
    # Remove deletion protection from database
    print_status "Removing database deletion protection..."
    terraform apply -target=google_sql_database_instance.postgres -var="deletion_protection=false" -auto-approve || true
    
    # Destroy all resources
    print_status "Running terraform destroy..."
    terraform destroy -auto-approve
    
    cd ..
    
    print_status "Terraform resources destroyed!"
}

# Clean up local files
cleanup_local() {
    print_status "Cleaning up local files..."
    
    # Remove terraform state files
    rm -rf terraform/.terraform
    rm -f terraform/.terraform.lock.hcl
    rm -f terraform/terraform.tfstate*
    rm -f terraform/tfplan
    rm -f outputs.json
    
    print_status "Local cleanup completed!"
}

# Main destruction flow
main() {
    print_status "Starting Supabase GCP destruction..."
    
    confirm_destroy
    delete_kubernetes
    destroy_terraform
    cleanup_local
    
    print_status "Destruction completed!"
    print_warning "Remember to remove any DNS records pointing to the load balancer IP"
}

# Run main function
main "$@"