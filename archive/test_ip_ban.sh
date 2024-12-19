#!/bin/bash

# Import test utilities
source "$(dirname "$0")/test_utils.sh"

# Load environment variables
load_env

# Test IP banning functionality
test_ip_ban() {
    print_header "IP Banning Tests"
    local errors=0
    
    # Make a request and capture the source IP from the access log
    curl -s "http://localhost:${API_GATEWAY_PORT}/health" > /dev/null
    sleep 1  # Wait for log to be written
    local source_ip=$(docker exec api-gateway grep -m1 "GET /health" /var/log/nginx/access.log | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$source_ip" ]; then
        print_error "Could not detect source IP"
        return 1
    fi
    
    echo "Testing with source IP: $source_ip (detected from access log)"
    
    # Test 1: Trigger IP Ban
    print_test_description "Testing IP ban trigger"
    echo "Making requests to trigger rate limit violations"
    
    local violations=0
    local is_banned=false
    local total_requests=30
    
    for i in $(seq 1 $total_requests); do
        local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
        local status_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')
        
        case $status_code in
            200)
                echo "Request $i: OK"
                ;;
            429)
                ((violations++))
                echo "Request $i: Rate Limited (Violation $violations/${MAX_RATE_LIMIT_VIOLATIONS})"
                ;;
            403)
                if [ "$is_banned" = false ]; then
                    print_success "IP $source_ip successfully banned after $violations violations"
                    is_banned=true
                    break
                fi
                ;;
            *)
                print_error "Unexpected status code: $status_code"
                errors=$((errors + 1))
                ;;
        esac
    done
    
    if [ "$is_banned" = false ]; then
        print_error "IP $source_ip was not banned after $violations violations"
        errors=$((errors + 1))
    fi
    
    # Test 2: Verify Ban File
    print_test_description "Verifying banned_ips.conf"
    local banned_ips=$(docker exec api-gateway cat /etc/nginx/banned_ips.conf)
    
    # Get the current banned IP from the file
    local banned_ip=$(echo "$banned_ips" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$banned_ip" ]; then
        print_success "Found banned IP in banned_ips.conf: $banned_ip"
        # Update source_ip to match what's in the ban file
        source_ip=$banned_ip
    else
        print_error "No banned IP found in banned_ips.conf"
        echo "Current banned_ips.conf contents:"
        echo "$banned_ips"
        errors=$((errors + 1))
    fi
    
    # Test 3: Test Ban Duration
    print_test_description "Testing ban duration"
    echo "Making request while banned"
    response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 403 ]; then
        print_success "Request blocked while banned"
    else
        print_error "Request not blocked while banned (got $status_code, expected 403)"
        errors=$((errors + 1))
    fi
    
    echo "Waiting ${BAN_DURATION_SECONDS} seconds for ban to expire..."
    sleep $BAN_DURATION_SECONDS
    
    response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Ban lifted after ${BAN_DURATION_SECONDS} seconds"
    else
        print_error "Ban not lifted after ${BAN_DURATION_SECONDS} seconds (got $status_code, expected 200)"
        errors=$((errors + 1))
    fi
    
    # Test 4: Verify Ban Removal
    print_test_description "Verifying ban removal"
    banned_ips=$(docker exec api-gateway cat /etc/nginx/banned_ips.conf)
    
    if echo "$banned_ips" | grep -q "$source_ip"; then
        print_error "IP still in banned_ips.conf after ban duration"
        echo "Current banned_ips.conf contents:"
        echo "$banned_ips"
        errors=$((errors + 1))
    else
        print_success "IP removed from banned_ips.conf"
    fi
    
    # Test 5: Security Logging
    print_test_description "Verifying security logging"
    local security_log=$(docker exec api-gateway tail -n 100 /var/log/nginx/error.log)
    
    if echo "$security_log" | grep -q "Security Event \[RATE_LIMIT_WARNING\].*Violation count:"; then
        print_success "Rate limit violations logged"
    else
        print_error "Rate limit violations not logged"
        echo "Recent error log entries:"
        echo "$security_log" | grep -A 2 "Security Event \[RATE_LIMIT_WARNING\]" || true
        errors=$((errors + 1))
    fi
    
    if echo "$security_log" | grep -q "Security Event \[IP_BANNED\].*Ban Start:"; then
        print_success "IP ban logged"
    elif echo "$security_log" | grep -q "Security Event \[BANNED_REQUEST_BLOCKED\].*Ban expires in"; then
        print_success "IP ban logged (different format)"
    else
        print_error "IP ban not logged"
        echo "Recent error log entries:"
        echo "$security_log" | grep -A 2 "Security Event \[IP_BANNED\]" || true
        echo "$security_log" | grep -A 2 "Security Event \[BANNED_REQUEST_BLOCKED\]" || true
        errors=$((errors + 1))
    fi
    
    if echo "$security_log" | grep -q "Security Event \[BAN_EXPIRED\].*Ban expired at"; then
        print_success "IP unban logged"
    else
        print_error "IP unban not logged"
        echo "Recent error log entries:"
        echo "$security_log" | grep -A 2 "Security Event \[BAN_EXPIRED\]" || true
        errors=$((errors + 1))
    fi
    
    # Print summary
    print_header "Test Summary"
    if [ $errors -eq 0 ]; then
        print_success "All IP ban tests passed successfully!"
    else
        print_error "IP ban tests completed with $errors error(s)"
    fi
    
    return $errors
}

# Run tests
setup
test_ip_ban