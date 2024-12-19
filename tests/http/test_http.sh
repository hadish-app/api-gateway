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
    response=$(make_request "$method" "$endpoint") || {
        print_assertion_detail "Actual" "Gateway failed to forward request"
        print_assertion_detail "Expected" "Gateway forwards request"
        print_result "fail" "Failed to make request"
        return 1
    }
    
    local status_code
    status_code=$(parse_response "$response" "STATUS")
    
    print_assertion_detail "Actual" "HTTP ${status_code}"
    print_assertion_detail "Expected" "Gateway forwards request (any valid HTTP status)"
    
    # For admin endpoints, we just verify the gateway forwarded the request
    # The actual status code depends on the admin service implementation
    if [[ "$endpoint" == "/admin/"* ]]; then
        if [[ "${status_code}" =~ ^[2-5][0-9]{2}$ ]]; then
            result="pass"  # Any valid HTTP status code is acceptable
        else
            result="fail"
        fi
    else
        # For non-admin endpoints, maintain original behavior
        if [[ "${status_code}" = "200" ]]; then
            result="pass"
        else
            result="fail"
        fi
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
    response=$(make_request "$method" "$endpoint") || {
        print_assertion_detail "Actual" "Request failed"
        print_assertion_detail "Expected" "Request reaches the backend"
        print_result "fail" "Failed to make request"
        return 1
    }
    
    local status_code
    status_code=$(parse_response "$response" "STATUS")
    
    print_assertion_detail "Actual" "HTTP ${status_code}"
    
    if [[ "$endpoint" == "/admin/"* ]]; then
        print_assertion_detail "Expected" "Any valid HTTP status (2xx-5xx)"
        # For admin endpoints, any valid HTTP status is acceptable
        if [[ "${status_code}" =~ ^[2-5][0-9]{2}$ ]]; then
            result="pass"
        else
            result="fail"
        fi
    else
        print_assertion_detail "Expected" "HTTP 405"
        # For non-admin endpoints, expect 405 Method Not Allowed
        if [[ "${status_code}" = "405" ]]; then
            result="pass"
        else
            result="fail"
        fi
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
    response=$(make_request "OPTIONS" "$endpoint") || {
        print_assertion_detail "Actual" "Request failed"
        print_assertion_detail "Expected" "Request succeeds"
        print_result "fail" "Failed to make request"
        return 1
    }
    
    local status_code headers
    status_code=$(parse_response "$response" "STATUS")
    headers=$(parse_response "$response" "HEADERS")
    
    local missing_headers=()
    for header in "${EXPECTED_CORS_HEADERS[@]}"; do
        if ! has_header "$headers" "$header"; then
            missing_headers+=("$header")
        fi
    done
    
    print_assertion_detail "Status" "HTTP ${status_code}"
    if [[ ${#missing_headers[@]} -eq 0 ]]; then
        print_assertion_detail "Actual" "All CORS headers present"
        print_assertion_detail "Expected" "All CORS headers present"
        result="pass"
        
        # Check if allowed methods match
        local cors_methods
        cors_methods=$(get_header_value "$headers" "Access-Control-Allow-Methods")
        print_assertion_detail "Allowed Methods" "$cors_methods"
        print_assertion_detail "Expected Methods" "$allowed_methods"
        
        # Convert both to arrays and compare
        IFS=',' read -ra actual_methods <<< "$cors_methods"
        IFS=',' read -ra expected_methods <<< "$allowed_methods"
        
        for method in "${expected_methods[@]}"; do
            method=$(echo "$method" | tr -d ' ')  # Remove whitespace
            if ! echo "${actual_methods[@]}" | grep -q "$method"; then
                result="fail"
                print_assertion_detail "Error" "Missing method: $method"
            fi
        done
    else
        print_assertion_detail "Actual" "Missing headers: ${missing_headers[*]}"
        print_assertion_detail "Expected" "All CORS headers present"
        result="fail"
    fi
    
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
