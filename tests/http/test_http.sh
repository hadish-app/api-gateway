#!/bin/bash

# Import common utilities
source tests/utils/common.sh

# Test configurations
readonly TEST_TIMEOUT=50  # milliseconds
readonly TEST_ENDPOINTS=(
    "/health:GET"
    "/admin/health:GET,POST,PUT,DELETE,OPTIONS"
)
readonly INVALID_METHODS=("PATCH" "TRACE" "CONNECT")
readonly EXPECTED_CORS_HEADERS=(
    "Access-Control-Allow-Origin"
    "Access-Control-Allow-Methods"
    "Access-Control-Allow-Headers"
    "Access-Control-Max-Age"
)

# Test assertions
test_valid_method() {
    local endpoint="$1"
    local method="$2"
    local result
    
    print_assertion "1" "Valid HTTP Method: $method $endpoint"
    print_assertion_detail "Testing" "API Gateway should forward $method requests"
    print_assertion_detail "Expression" "request is forwarded successfully"
    
    local response
    response=$(make_request_and_validate "$method" "$endpoint" "Gateway") || return 1
    
    local status_code
    status_code=$(parse_response "$response" "STATUS")
    
    print_assertion_detail "Actual" "HTTP ${status_code}"
    print_assertion_detail "Expected" "Gateway forwards request (any valid HTTP status)"
    
    # For admin endpoints, we just verify the gateway forwarded the request
    if [[ "$endpoint" == "/admin/"* ]]; then
        validate_http_status "$status_code" "" "true"
        result=$([[ $? -eq 0 ]] && echo "pass" || echo "fail")
    else
        validate_http_status "$status_code" "200"
        result=$([[ $? -eq 0 ]] && echo "pass" || echo "fail")
    fi
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

test_invalid_method() {
    local endpoint="$1"
    local method="$2"
    local result
    
    print_assertion "2" "Invalid HTTP Method: $method $endpoint"
    
    # Different behavior for admin vs non-admin endpoints
    if [[ "$endpoint" == "/admin/"* ]]; then
        print_assertion_detail "Testing" "API Gateway should forward invalid method to admin service"
        print_assertion_detail "Expression" "request is forwarded with valid HTTP status"
    else
        print_assertion_detail "Testing" "Endpoint should reject $method requests"
        print_assertion_detail "Expression" "status_code == 405"
    fi
    
    local response
    response=$(make_request_and_validate "$method" "$endpoint") || return 1
    
    local status_code
    status_code=$(parse_response "$response" "STATUS")
    
    print_assertion_detail "Actual" "HTTP ${status_code}"
    
    if [[ "$endpoint" == "/admin/"* ]]; then
        print_assertion_detail "Expected" "Any valid HTTP status (2xx-5xx)"
        validate_http_status "$status_code" "" "true"
        result=$([[ $? -eq 0 ]] && echo "pass" || echo "fail")
    else
        print_assertion_detail "Expected" "HTTP 405"
        validate_http_status "$status_code" "405"
        result=$([[ $? -eq 0 ]] && echo "pass" || echo "fail")
    fi
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

test_options_method() {
    local endpoint="$1"
    local allowed_methods="$2"
    local result
    
    print_assertion "3" "OPTIONS Method: $endpoint"
    print_assertion_detail "Testing" "Endpoint should return proper CORS headers"
    print_assertion_detail "Expression" "headers contain CORS information"
    
    local response
    response=$(make_request_and_validate "OPTIONS" "$endpoint") || return 1
    
    local status_code headers
    status_code=$(parse_response "$response" "STATUS")
    headers=$(parse_response "$response" "HEADERS")
    
    print_assertion_detail "Status" "HTTP ${status_code}"
    
    # Validate CORS headers and methods
    validate_cors_headers "$headers" "$allowed_methods"
    result=$([[ $? -eq 0 ]] && echo "pass" || echo "fail")
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

# Main test function
test_http_methods() {
    local test_title="HTTP Methods"
    local category="Basic HTTP Functionality"
    local description="Test HTTP method handling for all endpoints"
    local expectation="Endpoints should handle HTTP methods according to their configuration"
    
    print_box "Test ${test_title}"
    
    print_section "Category" && echo "  ${category}"
    print_section "Description" && echo "  ${description}"
    print_section "Expectation" && echo "  ${expectation}"
    
    local -i failed=0
    
    # Test each endpoint
    for endpoint_config in "${TEST_ENDPOINTS[@]}"; do
        local endpoint="${endpoint_config%%:*}"
        local methods="${endpoint_config#*:}"
        
        print_section "Testing Endpoint: $endpoint"
        echo -e "  ${BLUE}Allowed Methods:${NC} $methods"
        echo
        
        # Test valid methods
        IFS=',' read -ra VALID_METHODS <<< "$methods"
        for method in "${VALID_METHODS[@]}"; do
            test_valid_method "$endpoint" "$method" || ((failed++))
        done
        
        # Test invalid methods
        for method in "${INVALID_METHODS[@]}"; do
            test_invalid_method "$endpoint" "$method" || ((failed++))
        done
        
        # Test OPTIONS method
        test_options_method "$endpoint" "$methods" || ((failed++))
    done
    
    return $failed
}

# Run the test
test_http_methods
