#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | sed 's/\r$//' | xargs)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

URL="http://localhost:${API_GATEWAY_PORT}/admin/health"
TOTAL_REQUESTS=20

echo -e "${YELLOW}Starting Rate Limit Stress Test${NC}"
echo "Making $TOTAL_REQUESTS rapid requests to $URL"
echo -e "\nRate Limiting Parameters:"
echo "- ${RATE_LIMIT_REQUESTS} requests per second allowed"
echo "- Burst of ${RATE_LIMIT_BURST} additional requests"
echo "- IP banned after ${MAX_RATE_LIMIT_VIOLATIONS} violations"
echo "- Ban duration: ${BAN_DURATION_SECONDS} seconds"
echo -e "\nExpected behavior:"
echo "1. First $((RATE_LIMIT_REQUESTS + RATE_LIMIT_BURST)) requests should succeed ($RATE_LIMIT_REQUESTS normal + $RATE_LIMIT_BURST burst)"
echo "2. Then we should see rate limit errors (429)"
echo "3. After $MAX_RATE_LIMIT_VIOLATIONS violations, we should get banned (403)"
echo "4. Ban should lift after $BAN_DURATION_SECONDS seconds"
echo -e "${YELLOW}----------------------------------------${NC}\n"

# Function to make request and parse response
make_request() {
    local response=$(curl -s -w "\n%{http_code}" $URL)
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    case $status_code in
        200)
            echo -e "Request $1: ${GREEN}OK (200)${NC}"
            ;;
        429)
            echo -e "Request $1: ${YELLOW}Rate Limited (429)${NC}"
            echo -e "Response: $body"
            ;;
        403)
            echo -e "Request $1: ${RED}Banned (403)${NC}"
            echo -e "Response: $body"
            ;;
        *)
            echo -e "Request $1: Unknown Status ($status_code)"
            echo -e "Response: $body"
            ;;
    esac
}

# Make rapid requests
for i in $(seq 1 $TOTAL_REQUESTS); do
    make_request $i
    # No sleep - we want to trigger rate limiting
done

echo -e "\n${YELLOW}Waiting for ban to expire ($BAN_DURATION_SECONDS seconds)...${NC}"
sleep $BAN_DURATION_SECONDS

echo -e "\n${YELLOW}Testing if ban has been lifted...${NC}"
make_request "final"