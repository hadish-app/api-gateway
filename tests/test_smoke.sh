#!/bin/bash

# Import test utilities
source "$(dirname "$0")/test_utils.sh"

# Load environment variables
load_env

# Main test sequence
main() {
    print_header "API Gateway Smoke Tests"
    local errors=0
    
    # Test 1: Basic Health Check
    print_test_description "Testing health endpoint"
    local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/health")
    local status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Health check endpoint is responding"
    else
        print_error "Health check failed (status: $status_code)"
        errors=$((errors + 1))
    fi
    
    # Test 2: Admin Service Connectivity
    print_test_description "Testing admin service connectivity"
    response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Admin service is reachable"
        if echo "$body" | grep -q '"status":"ok"'; then
            print_success "Admin service reports healthy status"
        else
            print_error "Admin service reports unhealthy status"
            errors=$((errors + 1))
        fi
    else
        print_error "Admin service not reachable (status: $status_code)"
        errors=$((errors + 1))
    fi
    
    # Test 3: Security Headers
    print_test_description "Checking security headers"
    local headers=$(curl -s -I "http://localhost:${API_GATEWAY_PORT}/health")
    
    if ! echo "$headers" | grep -q "Server:"; then
        print_success "Server header is hidden"
    else
        print_warning "Server header is exposed (this is a known limitation)"
    fi
    
    if ! echo "$headers" | grep -q "X-Powered-By:"; then
        print_success "X-Powered-By header is hidden"
    else
        print_error "X-Powered-By header is exposed"
        errors=$((errors + 1))
    fi
    
    # Test 4: Invalid Route Handling
    print_test_description "Testing invalid route handling"
    response=$(curl -s -o /dev/null -w "%{size_download}" "http://localhost:${API_GATEWAY_PORT}/invalid_path")
    
    if [ "$response" = "0" ]; then
        print_success "Invalid route handled correctly (connection closed)"
    else
        print_error "Invalid route not handled correctly"
        errors=$((errors + 1))
    fi
    
    # Test 5: Invalid Method Handling
    print_test_description "Testing invalid method handling"
    response=$(curl -s -o /dev/null -w "%{size_download}" -X OPTIONS "http://localhost:${API_GATEWAY_PORT}/admin/health")
    
    if [ "$response" = "0" ]; then
        print_success "Invalid method handled correctly (connection closed)"
    else
        print_error "Invalid method not handled correctly"
        errors=$((errors + 1))
    fi
    
    # Test 6: Logging
    print_test_description "Verifying logging system"
    if docker exec api-gateway test -f /var/log/nginx/access.log; then
        print_success "Access log exists"
        if docker exec api-gateway grep -q "GET /health" /var/log/nginx/access.log; then
            print_success "Access log is being written to"
        else
            print_error "Access log is not being written to"
            errors=$((errors + 1))
        fi
    else
        print_error "Access log does not exist"
        errors=$((errors + 1))
    fi
    
    if docker exec api-gateway test -f /var/log/nginx/security.log; then
        print_success "Security log exists"
        if docker exec api-gateway grep -q "UNDEFINED_ROUTE" /var/log/nginx/security.log; then
            print_success "Security log is being written to"
        else
            print_error "Security log is not being written to"
            errors=$((errors + 1))
        fi
    else
        print_error "Security log does not exist"
        errors=$((errors + 1))
    fi
    
    # Print summary
    print_header "Test Summary"
    if [ $errors -eq 0 ]; then
        print_success "All smoke tests passed successfully!"
    else
        print_error "Smoke tests completed with $errors error(s)"
    fi
    
    return $errors
}

# Run tests
setup
main
  