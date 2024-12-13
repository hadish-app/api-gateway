# API Gateway Documentation

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

## Project Structure

### Root Directory
```
.
├── docker-compose.yaml    # Container orchestration
├── .env                   # Environment variables
├── .gitignore            # Git ignore rules
├── doc.md                # Project documentation
├── configs/              # Configuration files
├── logs/                 # Log files directory
└── test_api_gateway.sh   # Test script
```

### Configuration Files (`configs/`)
```
configs/
├── nginx.conf            # Main NGINX configuration
├── banned_ips.conf       # Dynamic banned IPs list
├── conf.d/              # Modular NGINX configurations
│   ├── basic.conf       # Basic NGINX settings
│   ├── security.conf    # Security settings
│   ├── logging.conf     # Logging configuration
│   ├── lua.conf         # Lua module loading
│   └── upstreams.conf   # Proxy settings
└── lua/modules/         # Lua modules
    ├── utils.lua        # Utility functions
    ├── config.lua       # Configuration management
    └── ip_ban.lua       # IP banning functionality
```

### File Descriptions

#### Root Directory Files
- `docker-compose.yaml`: Defines the container setup, including volume mounts, environment variables, and networking.
- `.env`: Contains environment variables for configuring the API Gateway behavior.
- `.gitignore`: Specifies which files Git should ignore.
- `doc.md`: Comprehensive project documentation (this file).
- `test_api_gateway.sh`: Test script to verify API Gateway functionality.

#### NGINX Configuration Files
- `configs/nginx.conf`: Main NGINX configuration file that includes:
  - Worker process settings
  - Environment variable declarations
  - Event loop configuration
  - HTTP server settings
  - Server block definitions

- `configs/banned_ips.conf`: Dynamic file managed by Lua code that contains:
  - Currently banned IP addresses
  - Ban duration information
  - Error response templates

#### Modular Configuration Files (`configs/conf.d/`)
- `basic.conf`: Basic NGINX settings including:
  - Buffer sizes
  - Timeouts
  - MIME types
  - Basic performance settings

- `security.conf`: Security-related configurations:
  - Rate limiting zones
  - IP blacklist settings
  - Security headers
  - Content Security Policy

- `logging.conf`: Logging configuration including:
  - Log formats
  - Log file locations
  - Buffer settings
  - Log rotation settings

- `lua.conf`: Lua module configuration:
  - Module loading
  - Package paths
  - Initialization code
  - Worker initialization

- `upstreams.conf`: Proxy and upstream settings:
  - Proxy headers
  - Timeouts
  - SSL settings
  - Load balancing configuration

#### Lua Modules (`configs/lua/modules/`)
- `utils.lua`: Utility functions including:
  - ISO8601 timestamp generation
  - Duration formatting
  - Common helper functions

- `config.lua`: Configuration management:
  - Environment variable loading
  - Default value handling
  - Configuration validation

- `ip_ban.lua`: IP banning functionality:
  - Ban implementation
  - Ban checking
  - Rate limit tracking
  - Ban file management

#### Log Files (`logs/`)
- `access.log`: HTTP access logs in JSON format containing:
  - Request details
  - Response status
  - Timing information
  - Client information

- `security.log`: Security event logs including:
  - Rate limit violations
  - IP ban events
  - Security-related warnings
  - Ban/unban operations

- `error.log`: Error logs containing:
  - NGINX errors
  - Lua errors
  - Configuration issues
  - System-level problems

### File Permissions
- Configuration files: Read-only in container
- Log files: Write access for NGINX worker process
- Banned IPs file: Write access for Lua code

### File Updates
- Most configuration files are static
- `banned_ips.conf` is dynamically updated by Lua code
- Log files are automatically rotated
- Configuration reloads do not require container restart

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
  