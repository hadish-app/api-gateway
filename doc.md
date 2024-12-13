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

### Test Phases
1. **Rate Limit Testing**
   - Sends rapid requests
   - Verifies 429 responses

2. **Ban Testing**
   - Triggers IP ban
   - Verifies 403 responses

3. **Unban Testing**
   - Waits for ban duration
   - Verifies access restoration

## Deployment

### Prerequisites
- Docker
- Docker Compose
- Minimum 512MB RAM
- Port 80 available

### Deployment Steps
1. Clone repository
2. Configure `.env` file
3. Run:
   ```bash
   docker compose up -d
   ```

### Health Check
Access `/admin/health` endpoint to verify deployment:
```bash
curl http://localhost/admin/health
```

## Troubleshooting

### Common Issues

1. **Rate Limiting Too Aggressive**
   - Check `limit_req_zone` settings
   - Adjust burst parameter
   - Verify client IP detection

2. **Ban Duration Issues**
   - Check `BAN_DURATION_SECONDS` in `.env`
   - Verify system time synchronization
   - Check log timestamps

3. **Log Issues**
   - Verify log directory permissions
   - Check available disk space
   - Validate log format configuration

### Debug Tools

1. **Log Analysis**
   ```bash
   tail -f logs/security.log
   tail -f logs/error.log
   ```

2. **Ban Status Check**
   ```bash
   cat configs/banned_ips.conf
   ```

3. **Configuration Test**
   ```bash
   docker exec api_gateway nginx -t
   ```

## Development Guide

### Adding New Features

1. **Modify Rate Limiting**
   - Edit `limit_req_zone` in nginx.conf
   - Update Lua violation tracking logic

2. **Custom Security Rules**
   - Add Lua functions in nginx.conf
   - Implement in `access_by_lua_block`

3. **New Endpoints**
   - Add location blocks in nginx.conf
   - Configure security parameters

### Best Practices

1. **Security**
   - Always validate client IP
   - Use secure headers
   - Implement request validation

2. **Performance**
   - Use shared memory judiciously
   - Implement caching where appropriate
   - Monitor resource usage

3. **Logging**
   - Maintain consistent log formats
   - Include request IDs
   - Log security events

### Code Style

1. **Lua Code**
   - Use clear function names
   - Comment complex logic
   - Handle errors gracefully

2. **Nginx Configuration**
   - Group related directives
   - Document non-obvious settings
   - Use consistent indentation

---

## Contributing
1. Fork the repository
2. Create feature branch
3. Submit pull request with tests
4. Update documentation

## License
This project is proprietary and confidential.

## Support
For support, contact the development team or create an issue in the repository. 