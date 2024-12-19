#!/bin/bash

# Import common utilities
source ../utils/common.sh

# Test configurations
readonly TEST_TIMEOUT=50  # milliseconds
readonly REQUIRED_FIELDS=(
    "status"
    "version"
    "metrics.memory"
    "metrics.bans"
    "metrics.config"
    "metrics.uptime_seconds"
)

# Test assertions
test_status_code() {
    local status_code="$1"
    local result
    
    print_assertion "1" "HTTP Status Code"
    print_assertion_detail "Testing" "Response should return HTTP 200 OK"
    print_assertion_detail "Expression" "status_code == 200"
    print_assertion_detail "Actual" "HTTP ${status_code}"
    print_assertion_detail "Expected" "HTTP 200"
    
    if [[ "${status_code}" = "200" ]]; then
        result="pass"
    else
        result="fail"
    fi
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

test_response_time() {
    local duration="$1"
    local result
    
    print_assertion "2" "Response Time"
    print_assertion_detail "Testing" "API should respond within acceptable time limit"
    print_assertion_detail "Expression" "response_time < ${TEST_TIMEOUT}ms"
    print_assertion_detail "Actual" "${duration}ms"
    print_assertion_detail "Expected" "< ${TEST_TIMEOUT}ms"
    
    if (( $(echo "$duration < $TEST_TIMEOUT" | bc -l) )); then
        result="pass"
    else
        result="fail"
    fi
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

test_json_format() {
    local body="$1"
    local result
    
    print_assertion "3" "Response Format"
    print_assertion_detail "Testing" "Response body should be valid JSON"
    print_assertion_detail "Expression" "is_valid_json(body)"
    print_assertion_detail "Actual" "$(is_valid_json "$body" && echo "Valid JSON" || echo "Invalid JSON")"
    print_assertion_detail "Expected" "Valid JSON"
    
    if is_valid_json "$body"; then
        result="pass"
    else
        result="fail"
    fi
    
    print_result "$result"
    echo
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

test_required_fields() {
    local body="$1"
    local -a missing_fields=()
    
    print_assertion "4" "Required Fields"
    print_assertion_detail "Testing" "Response should contain all required health check fields"
    print_assertion_detail "Expression" "check_required_fields(body)"
    
    echo -e "      ${BLUE}Checking fields:${NC}"
    for field in "${REQUIRED_FIELDS[@]}"; do
        if [[ "$(check_json_field "$body" "$field")" = "true" ]]; then
            local value
            value=$(get_json_field "$body" "$field")
            print_field_result "$field" "$value" "pass"
        else
            print_field_result "$field" "" "fail"
            missing_fields+=("$field")
        fi
    done
    
    print_assertion_detail "Actual" "${#missing_fields[@]} missing fields: ${missing_fields[*]:-None}"
    print_assertion_detail "Expected" "All fields present"
    print_result "$([[ ${#missing_fields[@]} -eq 0 ]] && echo "pass" || echo "fail")"
    echo
    
    return ${#missing_fields[@]}
}

test_status_value() {
    local body="$1"
    local expected_status="healthy"
    local result
    
    print_assertion "5" "Status Value"
    print_assertion_detail "Testing" "Health status should indicate healthy state"
    
    local status_value
    status_value=$(get_json_field "$body" "status")
    
    print_assertion_detail "Expression" "status == '${expected_status}'"
    print_assertion_detail "Actual" "$status_value"
    print_assertion_detail "Expected" "$expected_status"
    
    if [[ "$status_value" == "$expected_status" ]]; then
        result="pass"
    else
        result="fail"
    fi
    
    print_result "$result"
    return $([[ "$result" = "pass" ]] && echo 0 || echo 1)
}

# Main test function
test_health_check() {
    
    local test_title="Health Check Endpoint"
    local category="Basic HTTP Functionality"
    local description="Test the health check endpoint for proper response format and content"
    local expectation="Endpoint should return 200 OK with valid JSON containing all required metrics"
    
    print_box "Test ${test_title}"
    
    print_section "Category" && echo "  ${category}"
    print_section "Description" && echo "  ${description}"
    print_section "Expectation" && echo "  ${expectation}"
    
    print_section "Request"
    echo -e "  ${YELLOW}GET${NC} ${API_BASE_URL}/health"
    
    # Make the request
    local response
    response=$(make_request "GET" "/health") || {
        echo -e "${RED}Error: Failed to make request to health endpoint${NC}"
        return 1
    }
    
    # Parse response
    local status_code duration headers body
    status_code=$(parse_response "$response" "STATUS")
    duration=$(parse_response "$response" "DURATION")
    headers=$(parse_response "$response" "HEADERS")
    body=$(parse_response "$response" "BODY")
    
    print_section "Response"
    echo -e "  ${BLUE}Status:${NC}    ${status_code}"
    echo -e "  ${BLUE}Duration:${NC}  ${duration} ms"
    
    print_section "Headers"
    echo "$headers" | sed 's/^/  /'
    
    print_section "Body"
    echo "$body" | sed 's/^/  /'
    
    print_section "Assertions"
    
    # Run all assertions
    local -i failed=0
    
    test_status_code "$status_code" || ((failed++))
    test_response_time "$duration" || ((failed++))
    test_json_format "$body" || ((failed++))
    
    local missing_fields=0
    test_required_fields "$body"
    missing_fields=$?
    ((failed += missing_fields))
    
    if [[ $missing_fields -eq 0 ]]; then
        test_status_value "$body" || ((failed++))
    fi
    
    return $failed
}

# Run the test
test_health_check
