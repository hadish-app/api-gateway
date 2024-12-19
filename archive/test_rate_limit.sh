#!/bin/bash

# Import test utilities
source "$(dirname "$0")/test_utils.sh"

# Load environment variables
load_env

# Function to get status symbol
get_status_symbol() {
    local actual=$1
    local expected=$2
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

# Test rate limiting functionality
test_rate_limit() {
    print_header "Rate Limiting Tests"
    
    # Log current configuration
    echo -e "${BOLD}Current Rate Limit Configuration:${NC}"
    echo "Requests per window: ${RATE_LIMIT_REQUESTS}"
    echo "Burst allowance: ${RATE_LIMIT_BURST}"
    echo "Time window: ${RATE_LIMIT_WINDOW} seconds"
    echo "Max violations: ${MAX_RATE_LIMIT_VIOLATIONS}"
    echo
    
    local errors=0
    local start_time=$(date +%s.%N)
    
    echo -e "${BOLD}Request-Response Flow:${NC}"
    echo "--------------------------------------------------------------------------------"
    
    # Test 1: Basic Rate Limit
    for i in $(seq 1 ${RATE_LIMIT_REQUESTS}); do
        local now=$(date +%s.%N)
        local elapsed=$(echo "$now - $start_time" | bc)
        
        local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
        local status_code=$(echo "$response" | tail -n1)
        
        echo -e "$(printf "%s #%-3s | %6.2fs | %-30s | → REQ | ← %-12s | Expected: %-12s | Basic req #%d" \
            "$(get_status_symbol $status_code 200)" \
            "$i" \
            "$elapsed" \
            "/admin/health" \
            "$(format_status $status_code)" \
            "200" \
            "$i")"
        
        if [ "$status_code" != "200" ]; then
            errors=$((errors + 1))
        fi
    done
    
    # Test 2: Burst Allowance
    for i in $(seq 1 ${RATE_LIMIT_BURST}); do
        local now=$(date +%s.%N)
        local elapsed=$(echo "$now - $start_time" | bc)
        
        local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
        local status_code=$(echo "$response" | tail -n1)
        
        echo -e "$(printf "%s #%-3s | %6.2fs | %-30s | → REQ | ← %-12s | Expected: %-12s | Burst req #%d" \
            "$(get_status_symbol $status_code 200)" \
            "$((RATE_LIMIT_REQUESTS + i))" \
            "$elapsed" \
            "/admin/health" \
            "$(format_status $status_code)" \
            "200" \
            "$i")"
        
        if [ "$status_code" != "200" ]; then
            errors=$((errors + 1))
        fi
    done
    
    # Test 3: Rate Limit Exceeded
    local now=$(date +%s.%N)
    local elapsed=$(echo "$now - $start_time" | bc)
    
    local response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    local status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n1)
    
    echo -e "$(printf "%s #%-3s | %6.2fs | %-30s | → REQ | ← %-12s | Expected: %-12s | Over limit" \
        "$(get_status_symbol $status_code 429)" \
        "$((RATE_LIMIT_REQUESTS + RATE_LIMIT_BURST + 1))" \
        "$elapsed" \
        "/admin/health" \
        "$(format_status $status_code)" \
        "429")"
    
    if [ "$status_code" != "429" ]; then
        errors=$((errors + 1))
    fi
    
    echo "--------------------------------------------------------------------------------"
    
    # Test 4: Rate Limit Headers
    echo -e "\nChecking rate limit headers:"
    local headers=$(curl -s -I "http://localhost:${API_GATEWAY_PORT}/admin/health")
    local limit_header=$(echo "$headers" | grep "X-RateLimit-Limit:" | cut -d' ' -f2 | tr -d '\r')
    local remaining_header=$(echo "$headers" | grep "X-RateLimit-Remaining:" | cut -d' ' -f2 | tr -d '\r')
    local reset_header=$(echo "$headers" | grep "X-RateLimit-Reset:" | cut -d' ' -f2 | tr -d '\r')
    
    # Validate limit header
    local expected_limit=$((RATE_LIMIT_REQUESTS + RATE_LIMIT_BURST))
    if [ "$limit_header" = "$expected_limit" ]; then
        echo -e "${GREEN}✓${NC} X-RateLimit-Limit matches configuration ($limit_header)"
    else
        echo -e "${RED}✗${NC} X-RateLimit-Limit mismatch (got: $limit_header, expected: $expected_limit)"
        errors=$((errors + 1))
    fi
    
    if [ ! -z "$remaining_header" ]; then
        echo -e "${GREEN}✓${NC} X-RateLimit-Remaining present ($remaining_header)"
    else
        echo -e "${RED}✗${NC} X-RateLimit-Remaining missing"
        errors=$((errors + 1))
    fi
    
    if [ ! -z "$reset_header" ]; then
        echo -e "${GREEN}✓${NC} X-RateLimit-Reset present (resets at: $(date -r $reset_header))"
    else
        echo -e "${RED}✗${NC} X-RateLimit-Reset missing"
        errors=$((errors + 1))
    fi
    
    # Test 5: Rate Limit Reset
    echo -e "\nTesting rate limit reset"
    echo "Waiting ${RATE_LIMIT_WINDOW} seconds for rate limit to reset..."
    sleep $RATE_LIMIT_WINDOW
    
    now=$(date +%s.%N)
    elapsed=$(echo "$now - $start_time" | bc)
    
    response=$(curl -s -w "\n%{http_code}" "http://localhost:${API_GATEWAY_PORT}/admin/health")
    status_code=$(echo "$response" | tail -n1)
    
    echo "--------------------------------------------------------------------------------"
    echo -e "$(printf "%s #%-3s | %6.2fs | %-30s | → REQ | ← %-12s | Expected: %-12s | After reset" \
        "$(get_status_symbol $status_code 200)" \
        "1" \
        "$elapsed" \
        "/admin/health" \
        "$(format_status $status_code)" \
        "200")"
    echo "--------------------------------------------------------------------------------"
    
    if [ "$status_code" != "200" ]; then
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