#!/bin/bash

# Import test utilities
source "$(dirname "$0")/test_utils.sh"

# Load environment variables
load_env

# Test rate limiting functionality
test_rate_limit() {
    print_header "Rate Limiting Tests"
    local errors=0
    
    # Test 1: Basic Rate Limit
    print_test_description "Testing basic rate limit"
    echo "Making ${RATE_LIMIT_REQUESTS} requests (should all succeed)"
    
    for i in $(seq 1 ${RATE_LIMIT_REQUESTS}); do
        local response=$(curl -s -I "http://localhost:${API_GATEWAY_PORT}/admin/health")
        if echo "$response" | grep -q "HTTP/1.1 200"; then
            print_success "Request $i: Allowed"
        else
            print_error "Request $i: Failed"
            errors=$((errors + 1))
        fi
    done
    
    # Test 2: Burst Allowance
    print_test_description "Testing burst allowance"
    echo "Making ${RATE_LIMIT_BURST} burst requests (should all succeed)"
    
    for i in $(seq 1 ${RATE_LIMIT_BURST}); do
        local response=$(curl -s -I "http://localhost:${API_GATEWAY_PORT}/admin/health")
        if echo "$response" | grep -q "HTTP/1.1 200"; then
            print_success "Burst request $i: Allowed"
        else
            print_error "Burst request $i: Failed"
            errors=$((errors + 1))
        fi
    done
    
    # Test 3: Rate Limit Exceeded
    print_test_description "Testing rate limit exceeded"
    echo "Making additional request (should be rate limited)"
    
    local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    local status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 429 ]; then
        print_success "Request correctly rate limited"
    else
        print_error "Request not rate limited (got $status_code, expected 429)"
        errors=$((errors + 1))
    fi
    
    # Test 4: Rate Limit Headers
    print_test_description "Checking rate limit headers"
    local headers=$(curl -s -I "http://localhost:${API_GATEWAY_PORT}/admin/health")
    
    if echo "$headers" | grep -q "X-RateLimit-Limit:"; then
        print_success "X-RateLimit-Limit header present"
    else
        print_error "X-RateLimit-Limit header missing"
        errors=$((errors + 1))
    fi
    
    if echo "$headers" | grep -q "X-RateLimit-Remaining:"; then
        print_success "X-RateLimit-Remaining header present"
    else
        print_error "X-RateLimit-Remaining header missing"
        errors=$((errors + 1))
    fi
    
    if echo "$headers" | grep -q "X-RateLimit-Reset:"; then
        print_success "X-RateLimit-Reset header present"
    else
        print_error "X-RateLimit-Reset header missing"
        errors=$((errors + 1))
    fi
    
    # Test 5: Rate Limit Reset
    print_test_description "Testing rate limit reset"
    echo "Waiting 1 second for rate limit to reset..."
    sleep 1
    
    response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Rate limit reset successfully"
    else
        print_error "Rate limit did not reset (got $status_code, expected 200)"
        errors=$((errors + 1))
    fi
    
    # Print summary
    print_header "Test Summary"
    if [ $errors -eq 0 ]; then
        print_success "All rate limit tests passed successfully!"
    else
        print_error "Rate limit tests completed with $errors error(s)"
    fi
    
    return $errors
}

# Run tests
setup
test_rate_limit 