#!/bin/bash
set -euo pipefail

# Script to generate JWT keys for Supabase

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Generate JWT secret
generate_jwt_secret() {
    print_status "Generating JWT secret..."
    JWT_SECRET=$(openssl rand -base64 32)
    echo "JWT_SECRET: $JWT_SECRET"
    echo ""
}

# Generate keys using Docker
generate_keys_with_docker() {
    print_status "Generating anon and service_role keys..."
    
    # Check if JWT secret is provided
    if [ -z "${JWT_SECRET:-}" ]; then
        print_warning "JWT_SECRET not set. Generating a new one..."
        JWT_SECRET=$(openssl rand -base64 32)
    fi
    
    # Create a temporary Node.js script
    cat > /tmp/generate-keys.js << 'EOF'
const jwt = require('jsonwebtoken');

const jwtSecret = process.env.JWT_SECRET;
const jwtExpiry = 315360000; // 10 years

if (!jwtSecret) {
    console.error('JWT_SECRET environment variable is required');
    process.exit(1);
}

// Generate anon key
const anonToken = jwt.sign({
    role: 'anon',
    aud: 'authenticated',
    iss: 'supabase'
}, jwtSecret, {
    expiresIn: jwtExpiry
});

// Generate service_role key
const serviceToken = jwt.sign({
    role: 'service_role',
    aud: 'authenticated',
    iss: 'supabase'
}, jwtSecret, {
    expiresIn: jwtExpiry
});

console.log('ANON_KEY:', anonToken);
console.log('');
console.log('SERVICE_ROLE_KEY:', serviceToken);
EOF

    # Run the script in a Node.js container
    docker run --rm \
        -v /tmp/generate-keys.js:/app/generate-keys.js \
        -e JWT_SECRET="$JWT_SECRET" \
        node:18-alpine \
        sh -c "npm install jsonwebtoken && node /app/generate-keys.js"
    
    # Clean up
    rm /tmp/generate-keys.js
}

# Generate keys using online tool
generate_keys_online() {
    print_status "Generate keys using the Supabase online tool:"
    echo ""
    echo "1. Visit: https://supabase.com/docs/guides/auth/jwts#generating-jwts"
    echo "2. Use this JWT secret: $JWT_SECRET"
    echo "3. Copy the generated anon and service_role keys"
    echo ""
}

# Main function
main() {
    echo "==================================="
    echo "Supabase Key Generator"
    echo "==================================="
    echo ""
    
    generate_jwt_secret
    
    # Check if Docker is available
    if command -v docker &> /dev/null; then
        print_status "Docker found. Generating keys locally..."
        generate_keys_with_docker
    else
        print_warning "Docker not found. Use the online tool instead."
        generate_keys_online
    fi
    
    echo ""
    echo "==================================="
    echo "Add these to your terraform.tfvars:"
    echo "==================================="
    echo "jwt_secret       = \"$JWT_SECRET\""
    echo "anon_key         = \"<GENERATED_ANON_KEY>\""
    echo "service_role_key = \"<GENERATED_SERVICE_ROLE_KEY>\""
    echo ""
    print_warning "Keep these keys secure and never commit them to version control!"
}

# Run main function
main "$@"