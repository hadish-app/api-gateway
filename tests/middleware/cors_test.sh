#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
BASE_URL="http://localhost:8080"
ALLOWED_ORIGIN="http://check.com"
DISALLOWED_ORIGIN="http://evil.com"

# Counter for tests
TOTAL_TESTS=0
PASSED_TESTS=0

# Function to format header value for display
format_header_value() {
    local header_name=$1
    local response_file=$2
    local value=$(grep -i "^$header_name:" "$response_file" | sed "s/^$header_name: //i" | tr -d '\r')
    if [ -z "$value" ]; then
        echo "<not present>"
    else
        echo "$value"
    fi
}

# Function to check and format response status
get_response_status() {
    local response_file=$1
    local status=$(head -n 1 "$response_file" | grep -o "HTTP/[0-9.]* [0-9]* [^$]*" | sed 's/HTTP\/[0-9.]*//g')
    if [ -z "$status" ]; then
        echo "<no status>"
    else
        echo "$status"
    fi
}

# Function to print test result with details
print_result() {
    local test_name=$1
    local result=$2
    local details=$3
    local expected_values=$4
    local actual_values=$5
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${BLUE}Test Case:${NC} $test_name"
    
    # Print expected values
    echo -e "${BLUE}Expected:${NC}"
    echo -e "$expected_values" | sed 's/^/  /'
    
    # Print actual values
    echo -e "${BLUE}Actual:${NC}"
    echo -e "$actual_values" | sed 's/^/  /'
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${YELLOW}Details: $details${NC}"
    fi
    echo -e "----------------------------------------"
}

# Function to check response headers and return formatted output
check_cors_headers() {
    local response_file=$1
    local expected_origin=$2
    local should_have_cors=$3
    local status=$(get_response_status "$response_file")
    local result=0
    
    # Build actual values string
    local actual_values="Status: $status\n"
    
    # Add standard response headers
    actual_values+="Server: $(format_header_value "Server" "$response_file")\n"
    actual_values+="Content-Type: $(format_header_value "Content-Type" "$response_file")\n"
    
    # Add CORS headers if they exist
    actual_values+="Access-Control-Allow-Origin: $(format_header_value "Access-Control-Allow-Origin" "$response_file")\n"
    actual_values+="Access-Control-Allow-Methods: $(format_header_value "Access-Control-Allow-Methods" "$response_file")\n"
    actual_values+="Access-Control-Allow-Headers: $(format_header_value "Access-Control-Allow-Headers" "$response_file")\n"
    actual_values+="Access-Control-Max-Age: $(format_header_value "Access-Control-Max-Age" "$response_file")\n"
    actual_values+="Access-Control-Allow-Credentials: $(format_header_value "Access-Control-Allow-Credentials" "$response_file")\n"
    actual_values+="Access-Control-Expose-Headers: $(format_header_value "Access-Control-Expose-Headers" "$response_file")"
    
    # Check CORS headers
    if [ "$should_have_cors" = true ] && ! grep -q "Access-Control-Allow-Origin: $expected_origin" "$response_file"; then
        result=1
    fi
    
    # Check required headers for non-CORS requests
    if [ "$should_have_cors" = false ]; then
        if grep -q "Access-Control-" "$response_file"; then
            result=1
        fi
    fi
    
    # Check all required security headers as per test matrix
    local security_headers=(
        "X-Content-Type-Options: nosniff"
        "X-Frame-Options: DENY"
        "X-XSS-Protection: 1; mode=block"
        "X-Request-ID:"
    )
    
    local missing_headers=()
    for header in "${security_headers[@]}"; do
        header_name=$(echo "$header" | cut -d':' -f1)
        header_value=$(echo "$header" | cut -d':' -f2- | sed 's/^ //')
        
        if ! grep -q "^$header_name:" "$response_file"; then
            result=1
            missing_headers+=("$header_name")
        else
            if [ ! -z "$header_value" ]; then
                if ! grep -q "^$header_name: $header_value" "$response_file"; then
                    result=1
                    missing_headers+=("$header_name (incorrect value)")
                fi
            fi
        fi
        actual_values+="\n$header_name: $(format_header_value "$header_name" "$response_file")"
    done
    
    # Add missing headers information if any
    if [ ${#missing_headers[@]} -ne 0 ]; then
        actual_values+="\n\nMissing or incorrect security headers:"
        for header in "${missing_headers[@]}"; do
            actual_values+="\n- $header"
        done
    fi
    
    echo "$actual_values"
    return $result
}

# Create temporary directory for response files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Starting CORS Tests..."
echo "===================="

# A. Simple CORS Requests
echo -e "\n${YELLOW}A. Testing Simple CORS Requests${NC}"

# Test A.1 - Basic allowed origin
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/A1" -H "Origin: $ALLOWED_ORIGIN" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/A1" "$ALLOWED_ORIGIN" true)
print_result "A.1 Basic allowed origin" $? "Expected CORS headers for allowed origin" "$expected_values" "$actual_values"

# Test A.2 - Disallowed origin
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/A2" -H "Origin: $DISALLOWED_ORIGIN" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/A2" "" false)
print_result "A.2 Disallowed origin" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# Test A.3 - Simple header
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/A3" -H "Origin: $ALLOWED_ORIGIN" -H "Accept: application/json" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/A3" "$ALLOWED_ORIGIN" true)
print_result "A.3 Simple header" $? "Expected CORS headers with simple Accept header" "$expected_values" "$actual_values"

# Test A.4 - Simple content-type
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/A4" -H "Origin: $ALLOWED_ORIGIN" -H "Content-Type: text/plain" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/A4" "$ALLOWED_ORIGIN" true)
print_result "A.4 Simple content-type" $? "Expected CORS headers with text/plain content-type" "$expected_values" "$actual_values"

# Test A.5 - Non-CORS request
expected_values="Status: 200 OK\nContent-Type: application/json\nNo CORS headers\nRequired Security Headers:\n- X-Content-Type-Options: nosniff\n- X-Frame-Options: DENY\n- X-XSS-Protection: 1; mode=block\n- X-Request-ID: [UUID]"
curl -s -D "${TEMP_DIR}/A5" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/A5" "" false)
print_result "A.5 Non-CORS request" $? "Expected no CORS headers and all security headers to be present" "$expected_values" "$actual_values"

# B. Preflighted Requests
echo -e "\n${YELLOW}B. Testing Preflighted Requests${NC}"

# Test B.1.1 - Valid preflight
expected_values="Status: 204 No Content\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Allow-Methods: GET,OPTIONS\nAccess-Control-Allow-Headers: content-type,user-agent\nAccess-Control-Max-Age: 3600\nVary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\nAll security headers present"
curl -s -D "${TEMP_DIR}/B1" -X OPTIONS \
    -H "Origin: $ALLOWED_ORIGIN" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: content-type" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/B1" "$ALLOWED_ORIGIN" true)
print_result "B.1.1 Valid preflight" $? "Expected 204 with CORS preflight headers" "$expected_values" "$actual_values"

# Test B.1.2 - Invalid origin preflight
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/B2" -X OPTIONS \
    -H "Origin: $DISALLOWED_ORIGIN" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: content-type" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/B2" "" false)
print_result "B.1.2 Invalid origin preflight" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# Test B.1.3 - Invalid method preflight
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/B3" -X OPTIONS \
    -H "Origin: $ALLOWED_ORIGIN" \
    -H "Access-Control-Request-Method: POST" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/B3" "" false)
print_result "B.1.3 Invalid method preflight" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# C. Special Cases
echo -e "\n${YELLOW}C. Testing Special Cases${NC}"

# Test C.1 - Null origin
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/C1" -H "Origin: null" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/C1" "" false)
print_result "C.1 Null origin" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# Test C.2 - Multiple origin headers
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/C2" -H "Origin: $ALLOWED_ORIGIN" -H "Origin: $DISALLOWED_ORIGIN" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/C2" "" false)
print_result "C.2 Multiple origin headers" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# Test C.3 - Origin with port
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/C3" -H "Origin: http://check.com:8080" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/C3" "" false)
print_result "C.3 Origin with port" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# D. Additional Compliance Tests
echo -e "\n${YELLOW}D. Testing Additional Compliance Cases${NC}"

# Test D.1 - Case sensitivity
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/D1" \
    -H "Origin: $ALLOWED_ORIGIN" \
    -H "Content-TYPE: text/plain" \
    -H "USER-AGENT: test" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/D1" "$ALLOWED_ORIGIN" true)
print_result "D.1 Case sensitivity" $? "Expected CORS headers despite case differences" "$expected_values" "$actual_values"

# Test D.2 - Wildcard origin
expected_values="Status: 403 Forbidden\nNo CORS headers expected"
curl -s -D "${TEMP_DIR}/D2" -H "Origin: *" "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/D2" "" false)
print_result "D.2 Wildcard origin" $? "Expected 403 Forbidden" "$expected_values" "$actual_values"

# Test D.4.1 - Credentials (Not Allowed)
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\n✗ No Access-Control-Allow-Credentials header\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/D4.1" \
    -H "Origin: $ALLOWED_ORIGIN" \
    -H "Cookie: session=123" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/D4.1" "$ALLOWED_ORIGIN" true)
print_result "D.4.1 Credentials (Not Allowed)" $? "Expected successful response without credentials header" "$expected_values" "$actual_values"

# Test D.4.2 - Credentials (Allowed) - This will fail in current config but included for completeness
expected_values="Status: 200 OK\nAccess-Control-Allow-Origin: $ALLOWED_ORIGIN\nAccess-Control-Allow-Credentials: true\nAccess-Control-Expose-Headers: X-Request-ID\nVary: Origin\nAll security headers present"
curl -s -D "${TEMP_DIR}/D4.2" \
    -H "Origin: $ALLOWED_ORIGIN" \
    -H "Cookie: session=123" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/D4.2" "$ALLOWED_ORIGIN" true)
print_result "D.4.2 Credentials (Allowed)" $? "Expected successful response with credentials allowed" "$expected_values" "$actual_values"

# Test D.4.3 - Credentials with Wildcard Origin
expected_values="Status: 403 Forbidden\nNo CORS headers\nContent-Type: text/plain\nContent-Length: 0\nAll security headers present"
curl -s -D "${TEMP_DIR}/D4.3" \
    -H "Origin: *" \
    -H "Cookie: session=123" \
    "${BASE_URL}/health" > /dev/null
actual_values=$(check_cors_headers "${TEMP_DIR}/D4.3" "" false)
print_result "D.4.3 Credentials with Wildcard Origin" $? "Expected rejection of credentials with wildcard origin" "$expected_values" "$actual_values"

# Print test summary with more details
echo -e "\n${YELLOW}Test Summary${NC}"
echo -e "${BLUE}Total tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed tests:${NC} $PASSED_TESTS"
echo -e "${RED}Failed tests:${NC} $((TOTAL_TESTS - PASSED_TESTS))"
echo -e "${BLUE}Success rate:${NC} $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%"

# Exit with status code based on test results
[ "$TOTAL_TESTS" -eq "$PASSED_TESTS" ]
