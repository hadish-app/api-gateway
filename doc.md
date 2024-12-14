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

## Deployment Guide

### Prerequisites
- Docker Engine (20.10.0 or higher)
- Docker Compose (2.0.0 or higher)
- Available ports:
  - 80 (API Gateway)
  - System Admin service port

### Development Environment Setup

1. **Get Local IP Address**
   ```bash
   # On macOS/Linux
   ifconfig | grep "inet " | grep -v 127.0.0.1
   
   # Expected output example:
   # inet 192.168.1.101 netmask 0xffffff00 broadcast 192.168.1.255
   ```

2. **Update Environment Variables**
   - Copy the example environment file:
     ```bash
     cp .env.example .env
     ```
   - Update the `ADMIN_SERVICE_URL` in `.env`:
     ```bash
     # Replace IP_ADDRESS with your local IP (e.g., 192.168.1.101)
     # Replace PORT with your System Admin service port (e.g., 58316)
     ADMIN_SERVICE_URL=http://IP_ADDRESS:PORT
     ```

3. **Create Required Directories**
   ```bash
   mkdir -p logs
   mkdir -p configs/conf.d
   mkdir -p configs/lua/modules
   ```

4. **Set File Permissions**
   ```bash
   # Make log directory writable
   chmod 777 logs
   
   # Make banned_ips.conf writable
   chmod 666 configs/banned_ips.conf
   ```

### Production Deployment

1. **Environment Configuration**
   - Review and adjust all settings in `.env`:
     ```bash
     # Adjust rate limiting
     RATE_LIMIT_REQUESTS=10
     RATE_LIMIT_BURST=5
     
     # Adjust ban duration
     BAN_DURATION_SECONDS=1800  # 30 minutes
     
     # Adjust logging
     LOG_LEVEL=warn
     LOG_BUFFER_SIZE=64k
     LOG_FLUSH_INTERVAL=5s
     
     # Adjust client settings
     CLIENT_MAX_BODY_SIZE=10M
     CLIENT_BODY_TIMEOUT=60
     CLIENT_HEADER_TIMEOUT=60
     ```

2. **Container Deployment**
   ```bash
   # Start the container
   docker compose up -d
   
   # Verify deployment
   docker compose ps
   
   # Check logs
   docker compose logs -f
   ```

3. **Health Check**
   ```bash
   # Test the health endpoint
   curl http://localhost/admin/health
   
   # Expected response:
   {
     "status": "ok",
     "message": "Healthy",
     "dbLatency": 0.964334,
     "eventStoreLatency": 7.859875,
     "documentDbLatency": 8.085542,
     "dbMessage": "Database is connected",
     "eventStoreMessage": "EventStore is connected",
     "documentDbMessage": "DocumentDB is connected",
     "uptime": 960.899615812,
     "timestamp": "2024-12-13T16:20:55.174Z"
   }
   ```

### Container Management

1. **Start Container**
   ```bash
   docker compose up -d
   ```

2. **Stop Container**
   ```bash
   docker compose down
   ```

3. **View Logs**
   ```bash
   # View all logs
   docker compose logs
   
   # Follow logs
   docker compose logs -f
   
   # View specific logs
   docker exec api_gateway tail -f /var/log/nginx/error.log
   docker exec api_gateway tail -f /var/log/nginx/access.log
   docker exec api_gateway tail -f /var/log/nginx/security.log
   ```

4. **Reload Configuration**
   ```bash
   docker exec api_gateway nginx -s reload
   ```

### Troubleshooting

1. **Check Container Status**
   ```bash
   docker compose ps
   docker stats api_gateway
   ```

2. **Verify Network Connectivity**
   ```bash
   # Test admin service connection
   curl -v http://localhost/admin/health
   
   # Check container network
   docker network inspect hadish_core-api-gateway-private
   ```

3. **Common Issues**

   a. Container fails to start:
   - Check port conflicts:
     ```bash
     lsof -i :80
     ```
   - Check log files:
     ```bash
     docker compose logs api_gateway
     ```

   b. Admin service unreachable:
   - Verify service IP and port:
     ```bash
     # Get your local IP
     ifconfig | grep "inet " | grep -v 127.0.0.1
     
     # Test direct connection to admin service
     curl http://IP_ADDRESS:PORT/api/health
     ```
   - Check network connectivity:
     ```bash
     docker exec api_gateway ping IP_ADDRESS
     ```

   c. Rate limiting issues:
   - Check rate limit settings in `.env`
   - Monitor security logs:
     ```bash
     docker exec api_gateway tail -f /var/log/nginx/security.log
     ```

### Performance Tuning

1. **Worker Processes**
   - Adjust `worker_processes` in `nginx.conf`:
     ```nginx
     # Auto-detect CPU cores (recommended)
     worker_processes auto;
     
     # Or set manually
     worker_processes 4;
     ```

2. **Worker Connections**
   - Adjust in `.env`:
     ```bash
     WORKER_CONNECTIONS=2048
     ```

3. **Buffer Sizes**
   - Adjust in `.env` for high-traffic scenarios:
     ```bash
     CLIENT_BODY_BUFFER_SIZE=32k
     CLIENT_HEADER_BUFFER_SIZE=2k
     LARGE_CLIENT_HEADER_BUFFERS_NUMBER=4
     LARGE_CLIENT_HEADER_BUFFERS_SIZE=8k
     ```

4. **Logging Performance**
   - Adjust buffer and flush settings:
     ```bash
     LOG_BUFFER_SIZE=64k
     LOG_FLUSH_INTERVAL=5s
     ```
  