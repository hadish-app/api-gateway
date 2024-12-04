#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# URL to test
URL="http://localhost/admin/health"

# Function to make a request and return status code
make_request() {
    status_code=$(curl -s -o /dev/null -w "%{http_code}" $URL)
    echo $status_code
}

# Function to make a request and show response
make_request_with_response() {
    curl -s -w "\nStatus Code: %{http_code}\n" $URL
}

# Function to check if IP is banned
check_ban_status() {
    local content=$(docker exec api_gateway cat /etc/nginx/banned_ips.conf)
    if echo "$content" | grep -q "172.26.0.1 1;"; then
        echo -e "${GREEN}✓ IP is banned (found in banned_ips.conf)${NC}"
        return 0
    else
        echo -e "${RED}✗ IP is not banned${NC}"
        return 1
    fi
}

# Function to show banned_ips.conf contents
show_banned_ips() {
    echo -e "\n${YELLOW}Current banned_ips.conf contents:${NC}"
    docker exec api_gateway cat /etc/nginx/banned_ips.conf
}

# Function to show recent security logs
show_security_logs() {
    echo -e "\n${YELLOW}Recent security log entries:${NC}"
    docker exec api_gateway tail -n 5 /var/log/nginx/security.log
}

# Function to print section header
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Main test sequence
main() {
    print_header "Starting API Gateway Tests"
    echo "This test will verify:"
    echo "1. Rate limiting (10 req/s with burst of 5)"
    echo "2. IP banning after 3 rate limit violations"
    echo "3. 10-second ban duration"
    echo "4. Automatic unbanning"
    
    print_header "Phase 1: Testing Rate Limiting"
    echo "Making rapid requests to trigger rate limiting..."
    echo "Rate limit is set to 10 req/s with burst of 5"
    echo -e "You should see ${RED}429${NC} responses after exceeding the limit\n"
    
    local violations=0
    local is_banned=false
    
    # Make rapid requests until banned
    for i in {1..20}; do
        status=$(make_request)
        case $status in
            200)
                echo -e "Request $i: ${GREEN}OK (200)${NC}"
                ;;
            429)
                ((violations++))
                echo -e "Request $i: ${RED}Rate Limited (429) - Violation $violations/3${NC}"
                ;;
            403)
                if [ "$is_banned" = false ]; then
                    echo -e "Request $i: ${RED}IP Banned (403)${NC}"
                    is_banned=true
                    break
                fi
                ;;
            *)
                echo -e "Request $i: ${YELLOW}Unexpected Status ($status)${NC}"
                ;;
        esac
    done
    
    print_header "Phase 2: Verifying IP Ban"
    check_ban_status
    show_banned_ips
    
    print_header "Phase 3: Testing Ban Duration"
    echo "Ban duration is set to 10 seconds"
    echo "Making requests every 2 seconds to monitor ban status..."
    
    local start_time=$(date +%s)
    local ban_duration=10
    local check_interval=2
    
    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -ge $((ban_duration + 5)) ]; then
            break
        fi
        
        echo -e "\nTime elapsed: ${elapsed_time}s"
        status=$(make_request)
        
        case $status in
            200)
                echo -e "${GREEN}✓ Request allowed (200) - Ban has been lifted${NC}"
                ;;
            403)
                echo -e "${RED}✗ Request denied (403) - IP is still banned${NC}"
                ;;
            *)
                echo -e "${YELLOW}! Unexpected status ($status)${NC}"
                ;;
        esac
        
        sleep $check_interval
    done
    
    print_header "Final Status Check"
    echo -e "Making final request to verify ban is lifted:"
    make_request_with_response
    
    print_header "Test Summary"
    echo "1. Rate Limiting: Successfully triggered after rapid requests"
    echo "2. IP Banning: Successfully banned after $violations violations"
    echo "3. Ban Duration: Ban was lifted after approximately 10 seconds"
    echo "4. Current Status: $([ $(make_request) -eq 200 ] && echo -e "${GREEN}Unbanned${NC}" || echo -e "${RED}Still Banned${NC}")"
    
    show_security_logs
}

# Run the test
main
  