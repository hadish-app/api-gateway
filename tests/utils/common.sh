#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test result symbols
readonly SYMBOL_PASS="[PASS]"
readonly SYMBOL_FAIL="[FAIL]"
readonly SYMBOL_INFO="[INFO]"
readonly SYMBOL_WARN="[WARN]"

# Global test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Environment setup
load_env() {
    local env_file=".env"
    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}Error: .env file not found at $env_file${NC}"
        exit 1
    fi
    set -a
    source "$env_file"
    set +a
}

init_test_env() {
    load_env
    verify_dependencies
    export API_BASE_URL="http://localhost:${API_GATEWAY_PORT}"
    trap cleanup EXIT
}

cleanup() {
    local exit_code=$?
    print_test_summary
    exit $exit_code
}

# Dependency checking
verify_dependencies() {
    local required_commands=("curl" "jq" "bc" "awk" "sed")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -ne 0 ]]; then
        echo -e "${RED}Error: Missing required commands: ${missing_commands[*]}${NC}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# HTTP utilities
make_request() {
    local method="$1"
    local endpoint="$2"
    local url="${API_BASE_URL}${endpoint}"
    local response
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s%N)
    response=$(curl -s -i -X "$method" "$url") || {
        echo -e "${RED}Error: Failed to make HTTP request to $url${NC}"
        return 1
    }
    end_time=$(date +%s%N)
    
    duration=$(echo "scale=2; ($end_time - $start_time) / 1000000" | bc)
    
    # Parse response parts
    local headers body status_code
    headers=$(echo "$response" | awk 'BEGIN {RS="\r\n\r\n"} NR==1')
    body=$(echo "$response" | awk 'BEGIN {RS="\r\n\r\n"} NR==2')
    status_code=$(echo "$headers" | grep -E "^HTTP" | awk '{print $2}')
    
    # Format output with raw headers
    echo -e "STATUS:$status_code\nDURATION:$duration\nHEADERS:\n$headers\nBODY:$body"
}

parse_response() {
    local response="$1"
    local field="$2"
    
    case "$field" in
        "HEADERS")
            # Extract everything between HEADERS: and BODY:
            echo "$response" | awk '/^HEADERS:/{p=1;next} /^BODY:/{p=0} p'
            ;;
        *)
            # For other fields, return the value after the first colon
            echo "$response" | grep "^$field:" | cut -d':' -f2-
            ;;
    esac
}

# Header utilities
has_header() {
    local headers="$1"
    local header_name="$2"
    echo "$headers" | grep -i "^${header_name}:" >/dev/null 2>&1
}

get_header_value() {
    local headers="$1"
    local header_name="$2"
    echo "$headers" | grep -i "^${header_name}:" | cut -d':' -f2- | tr -d ' '
}

# JSON utilities
is_valid_json() {
    jq -e . >/dev/null 2>&1 <<< "$1"
}

format_json() {
    jq '.' <<< "$1"
}

check_json_field() {
    local json="$1"
    local field="$2"
    local jq_path
    
    jq_path=$(echo "$field" | sed 's/\./\"].["/g')
    jq_path=".[\"$jq_path\"]"
    
    jq "has(\"${field%%.*}\") and (${jq_path} != null)" 2>/dev/null <<< "$json"
}

get_json_field() {
    local json="$1"
    local field="$2"
    local jq_path
    
    jq_path=$(echo "$field" | sed 's/\./\"].["/g')
    jq_path=".[\"$jq_path\"]"
    
    jq -r "$jq_path" 2>/dev/null <<< "$json"
}

# Output formatting
print_box() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo -e "\n${BLUE}┌$( printf '─%.0s' $(seq 1 $width) )┐${NC}"
    echo -e "${BLUE}│${NC}$( printf ' %.0s' $(seq 1 $padding) )${YELLOW}${title}${NC}$( printf ' %.0s' $(seq 1 $(( width - padding - ${#title} ))) )${BLUE}│${NC}"
    echo -e "${BLUE}└$( printf '─%.0s' $(seq 1 $width) )┘${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}${1}:${NC}"
}

print_assertion() {
    echo -e "  ${YELLOW}Assertion ${1}: ${2}${NC}"
}

print_assertion_detail() {
    echo -e "      ${BLUE}${1}:${NC} ${2}"
}

print_result() {
    local result="$1"
    local message="${2:-}"
    
    if [[ "$result" = "pass" ]]; then
        echo -e "      ${BLUE}Result:${NC} ${GREEN}${SYMBOL_PASS}${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "      ${BLUE}Result:${NC} ${RED}${SYMBOL_FAIL}${NC}"
        [[ -n "$message" ]] && echo -e "      ${RED}Details: ${message}${NC}"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

print_field_result() {
    local field="$1"
    local value="$2"
    local status="$3"
    
    if [[ "$status" = "pass" ]]; then
        echo -e "        ${GREEN}${SYMBOL_PASS}${NC} $field = $value"
    else
        echo -e "        ${RED}${SYMBOL_FAIL}${NC} $field (missing)"
    fi
}

print_test_summary() {
    # Only print summary if tests were run
    [[ $TOTAL_TESTS -eq 0 ]] && return 0
    
    local total_width=60
    echo -e "\n${BLUE}Test Summary:${NC}"
    echo -e "${BLUE}$(printf '─%.0s' $(seq 1 $total_width))${NC}"
    echo -e "Total Tests:  ${TOTAL_TESTS}"
    echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"
    echo -e "${BLUE}$(printf '─%.0s' $(seq 1 $total_width))${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}All tests passed successfully!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Please check the output above.${NC}"
        return 1
    fi
}

# API readiness check
wait_for_api() {
    local max_attempts=30
    local attempt=1
    local wait_seconds=1
    
    echo -e "${BLUE}Waiting for API to be ready...${NC}"
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s "${API_BASE_URL}/health" > /dev/null; then
            echo -e "${GREEN}API is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep $wait_seconds
        ((attempt++))
    done
    
    echo -e "\n${RED}Error: API did not become ready within ${max_attempts} seconds${NC}"
    return 1
}

# Initialize the test environment
init_test_env
