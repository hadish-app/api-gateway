#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
load_env() {
    if [ -f .env ]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ $line =~ ^#.*$ ]] && continue
            [[ -z $line ]] && continue
            # Extract variable and value
            if [[ $line =~ ^([^=]+)=(.*)$ ]]; then
                key=${BASH_REMATCH[1]}
                value=${BASH_REMATCH[2]}
                # Remove any trailing comments and whitespace
                value=$(echo "$value" | sed 's/[[:space:]]*#.*$//')
                export "$key=$value"
            fi
        done < .env
    else
        echo "Error: .env file not found"
        exit 1
    fi
}

# Print section header
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Print test description
print_test_description() {
    echo -e "${YELLOW}$1${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Make a request and return status code
make_request() {
    local url=$1
    status_code=$(curl -s -o /dev/null -w "%{http_code}" $url)
    echo $status_code
}

# Make a request and show response
make_request_with_response() {
    local url=$1
    curl -s -w "\nStatus Code: %{http_code}\n" $url
}

# Check if IP is banned
check_ban_status() {
    local content=$(docker exec api-gateway cat /etc/nginx/banned_ips.conf)
    if echo "$content" | grep -q "172.25.0.1 1;"; then
        print_success "IP is banned (found in banned_ips.conf)"
        return 0
    else
        print_error "IP is not banned"
        return 1
    fi
}

# Show banned_ips.conf contents
show_banned_ips() {
    echo -e "\n${YELLOW}Current banned_ips.conf contents:${NC}"
    docker exec api-gateway cat /etc/nginx/banned_ips.conf
}

# Show recent security logs
show_security_logs() {
    echo -e "\n${YELLOW}Recent security log entries:${NC}"
    docker exec api-gateway tail -n 5 /var/log/nginx/security.log
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    echo -n "Waiting for service to be ready"
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "\n${GREEN}Service is ready!${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done
    echo -e "\n${RED}Service failed to become ready within $max_attempts seconds${NC}"
    return 1
}

# Format timestamp for any OS
format_timestamp() {
    local timestamp=$1
    if [ -z "$timestamp" ]; then
        echo "N/A"
        return
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, convert epoch to human-readable
        TZ=UTC date -j -f %s "$timestamp" "+%H:%M:%S" 2>/dev/null || echo "$timestamp"
    else
        # On Linux
        date -d "@$timestamp" '+%H:%M:%S' 2>/dev/null || echo "$timestamp"
    fi
}

# Clean up function
cleanup() {
    print_header "Cleaning up"
    docker compose down > /dev/null 2>&1
}

# Set up function
setup() {
    print_header "Setting up test environment"
    docker compose down > /dev/null 2>&1
    docker compose up -d > /dev/null 2>&1
    wait_for_service "http://localhost:${API_GATEWAY_PORT}/health"
}

# Trap cleanup function
trap cleanup EXIT 