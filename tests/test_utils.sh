#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

# Format status code with color
format_status() {
    local code=$1
    case $code in
        200) echo "${GREEN}200 OK       ${NC}" ;;
        429) echo "${YELLOW}429 LIMITED  ${NC}" ;;
        403) echo "${RED}403 BANNED   ${NC}" ;;
        503) echo "${RED}503 ERROR    ${NC}" ;;
        *)   echo "${RED}$code UNKNOWN  ${NC}" ;;
    esac
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

# Wait for service to be ready
wait_for_service() {
    local url="http://localhost:${API_GATEWAY_PORT}/health"
    local max_attempts=30
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
    wait_for_service
}

# Trap cleanup function
trap cleanup EXIT