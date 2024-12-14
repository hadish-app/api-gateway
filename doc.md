# API Gateway

## Overview
This API Gateway serves as a reverse proxy and security layer for backend services. It provides rate limiting, IP banning, and security headers.

## Features
- Rate limiting (10 req/s with burst of 5)
- IP banning after 3 rate limit violations
- Configurable ban duration
- Automatic unbanning
- Security headers
- Detailed logging
- Modular configuration

## Configuration
All configuration is done through environment variables in the `.env` file:

### Service URLs
- `ADMIN_SERVICE_URL`: Backend service URL

### Rate Limiting
- `RATE_LIMIT_REQUESTS`: Requests per second (default: 10)
- `RATE_LIMIT_BURST`: Burst size (default: 5)
- `RATE_LIMIT_WINDOW`: Time window for violations (default: 60s)
- `MAX_RATE_LIMIT_VIOLATIONS`: Violations before ban (default: 3)

### IP Banning
- `BAN_DURATION_SECONDS`: Ban duration (default: 1800s)

### Logging
- `LOG_LEVEL`: Log level (default: warn)
- `LOG_BUFFER_SIZE`: Log buffer size (default: 4k)
- `LOG_FLUSH_INTERVAL`: Log flush interval (default: 1s)

## Testing
Run the test script to verify functionality:
```bash
./test_api_gateway.sh
```

The test script verifies:
1. Rate limiting
2. IP banning
3. Ban duration
4. Automatic unbanning

## Logs
Logs are stored in the `logs` directory:
- `access.log`: Access logs in JSON format
- `security.log`: Security events in JSON format
- `error.log`: Error logs

## Security Features
1. Rate Limiting
   - Limits requests per IP
   - Configurable burst allowance
   - Automatic IP banning for violations

2. IP Banning
   - Automatic banning after rate limit violations
   - Configurable ban duration
   - Automatic unbanning

3. Security Headers
   - Content Security Policy
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection
   - Referrer-Policy
   - Strict-Transport-Security
   - Permissions-Policy

4. Request Validation
   - Method validation
   - Path validation
   - Header validation

## Maintenance
- Logs are automatically rotated
- Banned IPs are automatically removed after ban expiration
- Configuration is reloaded without downtime