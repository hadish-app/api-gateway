# API Gateway Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Configuration](#configuration)
5. [Security Features](#security-features)
6. [Logging System](#logging-system)
7. [Testing](#testing)
8. [Deployment](#deployment)
9. [Troubleshooting](#troubleshooting)
10. [Development Guide](#development-guide)

## Overview
This API Gateway serves as a robust security layer and traffic management system for backend services. Built using OpenResty (a powerful Nginx distribution with Lua support), it provides rate limiting, IP banning, and request routing capabilities.

## Architecture

### Components
- **OpenResty/Nginx**: Core server handling HTTP requests
- **Lua Scripts**: Custom security and routing logic
- **Docker**: Containerization and deployment
- **Shared Memory Zones**: For storing rate limiting and IP ban data

### Network Flow
1. Client makes request to API Gateway
2. Request passes through security checks (rate limiting, IP ban check)
3. If passed, request is proxied to appropriate backend service
4. Response is returned to client

## Features

### Core Features
- Request routing and proxying
- Health checks for backend services
- Detailed logging with millisecond precision
- Docker-based deployment

### Security Features
1. **Rate Limiting**
   - 10 requests per second with burst of 5
   - Configurable limits per endpoint
   - Automatic violation tracking

2. **IP Banning**
   - Automatic IP banning after 3 rate limit violations
   - Configurable ban duration (default: 10 seconds)
   - Automatic unbanning system

3. **Request Filtering**
   - Path-based access control
   - Method restrictions
   - Header validation

## Configuration

### Environment Variables
File: `.env`
```env
ADMIN_SERVICE_URL=http://192.168.1.104:62390
BAN_DURATION_SECONDS=10  # Ban duration in seconds
```

### Docker Configuration
File: `docker-compose.yaml`
```yaml
services:
  nginx:
    image: openresty/openresty:alpine
    container_name: api_gateway
    env_file:
      - .env
    ports:
      - 80:80
    volumes:
      - ./configs/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro
      - ./configs/banned_ips.conf:/etc/nginx/banned_ips.conf
      - ./logs:/var/log/nginx
```

### Nginx Configuration
File: `configs/nginx.conf`

Key sections:
1. **Shared Memory Zones**
   ```nginx
   lua_shared_dict ip_blacklist 10m;    # Stores banned IPs
   lua_shared_dict rate_limit_count 10m; # Stores rate limit counters
   ```

2. **Rate Limiting Configuration**
   ```nginx
   limit_req_zone $binary_remote_addr zone=admin_limit:10m rate=10r/s;
   limit_req zone=admin_limit burst=5 nodelay;
   ```

3. **Logging Formats**
   ```nginx
   log_format main_ext escape=json '[$timestamp] $remote_addr - $remote_user '
                      '"$request" $status $body_bytes_sent '
                      '"$http_referer" "$http_user_agent" '
                      'forwarded_for="$http_x_forwarded_for" '
                      'req_time=$request_time '
                      'upstream_time="$upstream_response_time" '
                      'upstream_status="$upstream_status" '
                      'host="$host" '
                      'server_port="$server_port" '
                      'request_id="$request_id"';
   ```

## Security Features

### Rate Limiting System
The rate limiting system uses a combination of Nginx's built-in rate limiting and Lua-based tracking:

1. **First Layer**: Nginx rate limiting
   - 10 requests per second
   - Burst allowance of 5 requests
   - Configured using `limit_req_zone` and `limit_req`

2. **Second Layer**: Lua violation tracking
   - Tracks rate limit violations
   - Triggers IP ban after 3 violations
   - Resets counters after 60 seconds

### IP Banning System

#### Ban Implementation
```lua
function ban_ip(ip)
    local blacklist = ngx.shared.ip_blacklist
    local ban_duration = blacklist:get("ban_duration")
    local ban_until = ngx.time() + ban_duration
    
    -- Store ban information
    blacklist:set(ip, ban_until)
    
    -- Update banned_ips.conf
    update_banned_ips_file(ip, ban_until)
end
```

#### Ban Check Implementation
```lua
function is_ip_banned(ip)
    local blacklist = ngx.shared.ip_blacklist
    local ban_until = blacklist:get(ip)
    
    if ban_until then
        local current_time = ngx.time()
        return current_time < ban_until
    end
    return false
end
```

## Logging System

### Log Types

1. **Access Log** (`access.log`)
   - All HTTP requests
   - Response status
   - Timing information
   - Client details

2. **Security Log** (`security.log`)
   - Rate limit violations
   - IP ban events
   - Security-related events

3. **Error Log** (`error.log`)
   - System errors
   - Ban/unban operations
   - Configuration issues

### Log Format
All logs use ISO8601 timestamp format with millisecond precision:
```
[2024-12-04T15:37:46.450+00:00]
```

### Sample Log Entries

1. **Rate Limit Violation**
```
[2024-12-04T15:37:46.232+00:00] Security Event [RATE_LIMIT_WARNING] - IP: 172.26.0.1, Details: Violation count: 1/3
```

2. **IP Ban Event**
```
[2024-12-04T15:37:46.292+00:00] Security Event [IP_BANNED] - IP: 172.26.0.1, Ban Start: 2024-12-04 15:37:46, Ban Until: 2024-12-04 15:37:56
```

## Testing

### Test Script
File: `test_api_gateway.sh`

The test script verifies:
1. Rate limiting functionality
2. IP banning after violations
3. Ban duration accuracy
4. Automatic unbanning

### Running Tests
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
  