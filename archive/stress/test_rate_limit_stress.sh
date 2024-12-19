#!/bin/bash

# Import test utilities
source "$(dirname "$0")/../test_utils.sh"

# Load environment variables
load_env

# Test rate limiting under stress
test_rate_limit_stress() {
    print_header "Rate Limit Stress Test"
    local errors=0
    
    print_test_description "Test Configuration"
    echo "Rate Limiting Parameters:"
    echo "- ${RATE_LIMIT_REQUESTS} requests per second allowed"
    echo "- Burst of ${RATE_LIMIT_BURST} additional requests"
    echo "- Window size: 1 second"
    
    # Test 1: Concurrent Requests
    print_test_description "Testing concurrent requests"
    local concurrent=10
    local total_requests=50
    local temp_dir=$(mktemp -d)
    
    echo "Making $total_requests requests with concurrency of $concurrent"
    
    # Create URLs file
    for i in $(seq 1 $total_requests); do
        echo "http://localhost:${API_GATEWAY_PORT}/admin/health" >> "$temp_dir/urls.txt"
    done
    
    # Use curl to make concurrent requests
    curl -s -K- < <(while read url; do echo "url = $url"; done < "$temp_dir/urls.txt") \
         --parallel --parallel-max $concurrent \
         -w "%{http_code}\n" -o /dev/null > "$temp_dir/results.txt"
    
    # Analyze results
    local success_count=$(grep -c "^200$" "$temp_dir/results.txt")
    local rate_limited_count=$(grep -c "^429$" "$temp_dir/results.txt")
    local other_count=$(grep -cv "^2[0-9][0-9]\|^429$" "$temp_dir/results.txt")
    
    echo "Results:"
    echo "- Successful requests (200): $success_count"
    echo "- Rate limited requests (429): $rate_limited_count"
    echo "- Other responses: $other_count"
    
    # Verify expected behavior
    local expected_success=$((RATE_LIMIT_REQUESTS + RATE_LIMIT_BURST))
    if [ $success_count -ge $expected_success ]; then
        print_success "Expected number of successful requests"
    else
        print_error "Too few successful requests (got $success_count, expected at least $expected_success)"
        errors=$((errors + 1))
    fi
    
    if [ $rate_limited_count -gt 0 ]; then
        print_success "Rate limiting triggered as expected"
    else
        print_error "No rate limiting triggered"
        errors=$((errors + 1))
    fi
    
    if [ $other_count -eq 0 ]; then
        print_success "No unexpected responses"
    else
        print_error "Got $other_count unexpected responses"
        errors=$((errors + 1))
    fi
    
    # Test 2: Rapid Sequential Requests
    print_test_description "Testing rapid sequential requests"
    local rapid_requests=20
    
    echo "Making $rapid_requests rapid sequential requests..."
    for i in $(seq 1 $rapid_requests); do
        curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:${API_GATEWAY_PORT}/admin/health" >> "$temp_dir/rapid_results.txt" &
    done
    wait
    
    # Analyze rapid results
    success_count=$(grep -c "^200$" "$temp_dir/rapid_results.txt")
    rate_limited_count=$(grep -c "^429$" "$temp_dir/rapid_results.txt")
    other_count=$(grep -cv "^2[0-9][0-9]\|^429$" "$temp_dir/rapid_results.txt")
    
    echo "Rapid Test Results:"
    echo "- Successful requests (200): $success_count"
    echo "- Rate limited requests (429): $rate_limited_count"
    echo "- Other responses: $other_count"
    
    if [ $success_count -le $((RATE_LIMIT_REQUESTS + RATE_LIMIT_BURST)) ]; then
        print_success "Rate limit enforced correctly"
    else
        print_error "Too many requests succeeded"
        errors=$((errors + 1))
    fi
    
    # Test 3: Recovery Time
    print_test_description "Testing recovery time"
    echo "Waiting 1 second for rate limit to reset..."
    sleep 1
    
    local recovery_response=$(curl -s -w "%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    if [ "$recovery_response" -eq 200 ]; then
        print_success "System recovered after wait period"
    else
        print_error "System did not recover (got $recovery_response, expected 200)"
        errors=$((errors + 1))
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Print summary
    print_header "Test Summary"
    if [ $errors -eq 0 ]; then
        print_success "All stress tests passed successfully!"
    else
        print_error "Stress tests completed with $errors error(s)"
    fi
    
    return $errors
}

# Run tests
setup
test_rate_limit_stress