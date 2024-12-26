I'll create a comprehensive document about the project. Let me structure it properly:

# Hadish API Gateway - Technical Documentation

## 1. Project Overview

### 1.1 Purpose

Hadish API Gateway serves as the central entry point for a microservices architecture, managing and routing API requests from web frontend applications to various backend microservices. It's built using OpenResty (Nginx + Lua) to provide high performance and flexibility.

### 1.2 Key Features

- Service routing
- Security and authentication
- Rate limiting and DDoS protection
- Health monitoring and circuit breaking
- Metrics collection and logging
- WAF (Web Application Firewall)
- Integration testing support

### 1.3 Feature List

#### Core Features

1. **Service Routing & Proxy**

   - [ ] Basic HTTP proxy functionality
   - [ ] Static route configuration via location files
   - [ ] Path-based routing
   - [ ] Method-based routing (GET, POST, etc.)
   - [ ] Header manipulation
   - [ ] Upstream timeout handling

2. **Security & Protection**

   - [ ] WAF implementation
     - [ ] Basic rule set
     - [ ] SQL injection protection
     - [ ] XSS protection
   - [ ] CORS (Cross-Origin Resource Sharing)
     - [ ] Configurable allowed origins
     - [ ] Methods (GET, POST, etc.)
     - [ ] Headers
     - [ ] Credentials handling
     - [ ] Preflight requests (OPTIONS)
   - [ ] Rate limiting
     - [ ] Global rate limiting
     - [ ] IP-based rate limiting
     - [ ] Configurable time windows
   - [ ] IP blocking
     - [ ] Manual IP blacklist
     - [ ] Automatic blocking based on violations
     - [ ] IP ban duration management

3. **Health & Circuit Breaking**

   - [ ] Health check implementation
     - [ ] Configurable intervals
     - [ ] Timeout settings
     - [ ] Custom health check endpoints
   - [ ] Circuit breaker
     - [ ] Error threshold configuration
     - [ ] Recovery time settings
     - [ ] Half-open state handling

4. **Logging & Monitoring**
   - [ ] Error logging
     - [ ] Configurable log levels
     - [ ] File and stderr output
   - [ ] Access logging
     - [ ] JSON format
     - [ ] Configurable fields
   - [ ] Metrics collection
     - [ ] Request/Response timing
     - [ ] Error rates
     - [ ] Resource usage

#### Extended Features

1. **Advanced Security**

   - [ ] Custom WAF rules
   - [ ] Advanced rate limiting strategies
   - [ ] Security event detection
   - [ ] Threat monitoring

2. **Performance Optimization**

   - [ ] Response caching
   - [ ] Request/Response compression
   - [ ] Connection pooling
   - [ ] Buffer optimization

3. **Advanced Monitoring**

   - [ ] Custom metrics
   - [ ] Performance dashboards
   - [ ] Alert system
   - [ ] Traffic analysis

4. **Developer Tools**
   - [ ] Debug endpoints
   - [ ] Testing utilities
   - [ ] Configuration validation
   - [ ] Development mode

#### Administrative Features

1. **Configuration Management**

   - [ ] Runtime configuration updates
   - [ ] Configuration validation
   - [ ] Configuration backup/restore
   - [ ] Environment management

2. **Maintenance Tools**
   - [ ] Log rotation
   - [ ] Log archival
   - [ ] System cleanup
   - [ ] Resource management

#### Implementation Guidelines

1. **Development Process**

   - Each feature requires:
     - Design documentation
     - Implementation plan
     - Test cases
     - Integration tests
     - Performance validation

2. **Testing Requirements**

   - Unit tests for core functionality
   - Integration tests for feature combinations
   - Performance tests for critical paths
   - Security validation for protection features

3. **Documentation Requirements**

   - Technical specifications
   - API documentation
   - Configuration guides
   - Deployment instructions

4. **Quality Standards**
   - Code style consistency
   - Error handling
   - Performance benchmarks
   - Security best practices

## 2. Architecture

### 2.1 Core Components

```
/
├── configs/                 # Nginx and OpenResty configurations
│   ├── core/               # Core Nginx configurations
│   ├── locations/          # Service routing configurations
│   ├── lua/               # Lua-specific configurations
│   └── nginx.conf         # Main configuration file
├── modules/                # Lua modules
│   ├── core/              # Core functionality
│   ├── middleware/        # Request/Response middleware
│   ├── services/          # Service-specific handlers
│   └── utils/             # Utility functions
├── tests/                  # Test suites
└── docker-compose.yaml     # Deployment configuration
```

### 2.2 Request Flow

```
Client Request
    → WAF (Security Check)
    → CORS Check & Headers
        ↳ If OPTIONS: Handle Preflight & Return
        ↳ If Normal: Add CORS Headers
    → Rate Limiting
    → Service Routing
    → Circuit Breaker
    → Upstream Service
    → Add CORS Headers
    → Client Response
```

## 3. Core Functionality

### 3.1 Service Routing

- Static configuration through location files
- Service-specific handlers in `modules/services/`
- Health checking
- Circuit breaker for failing services

### 3.2 Security Features

- WAF for basic attack protection
- Global rate limiting
- IP banning for malicious activities

### 3.3 Monitoring and Metrics

#### Performance Metrics

- Request/Response timing
- Throughput rates
- Error rates
- Service health status

#### Security Metrics

- Rate limit violations
- Blocked IPs
- Suspicious traffic patterns
- WAF triggers

#### Resource Metrics

- Connection counts
- Bandwidth usage
- Worker process status

### 3.4 Logging

#### Current Implementation

- **Error Logging**

  - Dual output to file (`/usr/local/openresty/nginx/logs/error.log`) and stderr
  - Error-level logging for critical issues
  - Configured in core context for global error capture

- **Access Logging**
  - JSON-formatted logging for machine readability
  - Structured fields including:
    - Timestamp (ISO 8601)
    - Client information (IP, user)
    - Request details
    - Response status and size
    - Performance metrics (request time)
    - Forwarding information

#### Planned Features

- **Middleware Logging**

  - Structured logging format
  - Console and file outputs
  - Log rotation support
  - Integrated metrics collection

- **Log Levels**

  - ERROR: System errors and critical issues
  - WARN: Important events that need attention
  - INFO: General operational information
  - DEBUG: Detailed debugging information

- **Performance Logging**

  - Request/Response timing
  - Upstream service latency
  - System resource usage

- **Security Logging**
  - WAF events
  - Rate limiting violations
  - IP blocking events
  - Suspicious activity detection

#### Log Management

- Log rotation and archival
- Configurable retention periods
- Compression for archived logs
- Log shipping support (planned)

## 4. Service Integration

### 4.1 Service Configuration

Services can be configured using either static or dynamic (environment-based) approaches. Both methods have their use cases and trade-offs.

#### A. Basic Approach (Static Configuration)

1. **Location Configuration** (`/configs/locations/*.conf`)

   ```nginx
   # Simple and direct configuration
   location /api/service {
       access_by_lua_file modules/services/new_service.lua;
       proxy_pass http://upstream_service;
   }
   ```

2. **Service Handler** (`/modules/services/*.lua`)

   ```lua
   local _M = {}

   function _M.handle()
       -- Pre-processing logic
       -- Authentication/Authorization
       -- Request validation
       -- Error handling
   end

   return _M
   ```

**Use Case**: Development environments or when upstream services are stable and rarely change.

#### B. Dynamic Approach (Environment-Based)

1. **Location Configuration**

   ```nginx
   # Environment-based configuration
   location /api/service {
       access_by_lua_block {
           local config = require("core.config")
           local upstream, err = config.get("service", "service_upstream")
           if not upstream then
               ngx.log(ngx.ERR, "Failed to get upstream: ", err)
               ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
           end

           ngx.var.upstream = upstream
           require("services.service_name").handle()
       }
       proxy_pass $upstream;
   }
   ```

2. **Service Handler**

   ```lua
   local _M = {}
   local config = require("core.config")

   function _M.get_upstream()
       return config.get("service", "service_upstream")
   end

   function _M.handle()
       -- Service logic with dynamic configuration
   end

   return _M
   ```

**Use Case**: Production environments or when upstream services need to be configurable without gateway restart.

### 4.2 Configuration Options

#### A. Environment Variables

```env
# Service Upstream Configuration
SERVICE_USER_UPSTREAM="http://user-service:3000"
SERVICE_AUTH_UPSTREAM="http://auth-service:3000"
SERVICE_PAYMENT_UPSTREAM="http://payment-service:3000"

# Service-specific Settings
SERVICE_USER_TIMEOUT=60
SERVICE_USER_MAX_CONNS=100
```

#### B. Configuration Management

1. **Loading Configuration**

   ```lua
   -- Using core.config module
   local config = require("core.config")
   local success, err = config.init()  -- Load from environment
   ```

2. **Accessing Configuration**

   ```lua
   -- Get specific service configuration
   local upstream = config.get("service", "user_upstream")
   local timeout = config.get("service", "user_timeout")
   ```

3. **Runtime Updates**
   ```lua
   -- Update service configuration
   local success, err = config.set("service", "user_upstream", "http://new-host:3000")
   ```

#### C. Configuration Hierarchy

1. **Default Values**

   - Defined in code
   - Provides fallback options

2. **Environment Variables**

   - Overrides defaults
   - Environment-specific settings

3. **Runtime Updates**
   - Temporary changes
   - No persistence across restarts

### 4.3 Best Practices

1. **Configuration Choice**

   - Use dynamic configuration

2. **Error Handling**

   - Always validate configuration values
   - Provide meaningful error messages
   - Have fallback options where appropriate

3. **Security**

   - Validate upstream URLs
   - Sanitize configuration values
   - Restrict runtime configuration updates

4. **Maintenance**
   - Document all configuration options
   - Version control static configurations
   - Monitor configuration changes

Key configuration aspects:

- Environment-based service discovery
- Centralized configuration management
- Runtime update capabilities
- Error handling and validation
- Security considerations

## 5. Development

### 5.1 Development Environment

- Docker-based development environment
- OpenResty 1.21.4.1-6-alpine-fat base image
- Environment configuration through `.env` file

### 5.2 Testing Strategy

- Integration tests for service routing
- Health check testing
- Security feature testing
- Load testing (planned)

### 5.3 Dependencies (OPM Packages)

```
Security:
- lua-resty-waf         # WAF implementation
- lua-resty-iputils     # IP utilities

Core Functionality:
- lua-resty-healthcheck # Service health checking
- lua-resty-circuit-breaker # Circuit breaking
- lua-resty-logger-socket  # Enhanced logging
```

## 6. Deployment

### 6.1 Requirements

- Docker and Docker Compose
- Environment configuration file
- Service configurations

### 6.2 Configuration

#### Environment Variables

```env
# Server Configuration
SERVER_PORT=8080
SERVER_WORKER_PROCESSES=auto
SERVER_WORKER_CONNECTIONS=1024

# Security Configuration
SECURITY_RATE_LIMIT_REQUESTS=100
SECURITY_RATE_LIMIT_WINDOW=60
SECURITY_IP_BAN_MAX_FAILS=10
SECURITY_IP_BAN_DURATION=3600

# CORS Configuration
CORS_ENABLED=true
CORS_ALLOW_ORIGINS="*"  # Comma-separated list or * for all
CORS_ALLOW_METHODS="GET,POST,PUT,DELETE,OPTIONS"
CORS_ALLOW_HEADERS="Content-Type,Authorization"
CORS_ALLOW_CREDENTIALS=false
CORS_MAX_AGE=3600

# Cache Configuration
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=3600

# Monitoring Configuration
MONITORING_ENABLED=true
MONITORING_METRICS_ENABLED=true
```

### 6.3 Deployment Process

1. Configure environment variables
2. Set up service configurations
3. Deploy using Docker Compose
4. Verify health endpoints
5. Monitor metrics and logs

## 7. Performance Requirements

### 7.1 Latency

- Minimal gateway overhead
- Optimized worker processes
- Efficient request routing

### 7.2 Scalability

- Horizontal scaling through Docker
- Resource optimization

### 7.3 Reliability

- Circuit breaker implementation
- Health monitoring
- Automatic recovery mechanisms

## 8. Security Requirements

### 8.1 Authentication

- Future authentication methods to be determined
- No token issuance (handled by auth service)

### 8.2 Rate Limiting

- Global rate limiting
- IP-based rate limiting
- Configurable windows and limits

### 8.3 WAF Features

- SQL injection protection
- XSS protection
- Common attack pattern detection
- Custom rule support

## 9. Monitoring and Observability

### 9.1 Metrics Collection

- Performance metrics
- Security metrics
- Resource utilization
- Custom metric support

### 9.2 Logging

- Structured logging
- Debug-level detail
- Performance logging
- Security event logging
