# API Gateway Project Analysis

## Project Overview
A high-performance API Gateway built with OpenResty (Nginx + Lua) that provides:
- Rate limiting with burst allowance
- Automatic IP banning for repeat offenders
- Detailed security logging
- Modular Lua codebase
- Environment-based configuration

## Project Structure
```
.
├── .env                        # Environment configuration
├── .gitignore                 # Git ignore patterns
├── configs/
│   ├── nginx.conf             # Main Nginx configuration
│   └── banned_ips.conf        # Dynamic IP ban list (auto-generated)
├── modules/
│   ├── admin.lua              # Admin service request handling
│   ├── ip_ban.lua             # IP banning functionality
│   ├── rate_limit.lua         # Rate limit violation handling
│   ├── rate_limiter.lua       # Rate limiting core logic
│   ├── utils.lua              # Shared utility functions
│   └── config/
│       ├── admin.lua          # Admin service configuration
│       ├── ip_ban.lua         # IP ban configuration
│       ├── logging.lua        # Logging configuration
│       ├── rate_limit.lua     # Rate limit configuration
│       └── utils.lua          # Configuration utilities
├── tests/
│   ├── test_rate_limit.sh     # Rate limit testing
│   └── test_rate_limit_stress.sh  # Stress testing
└── docker-compose.yaml        # Docker configuration
```

## Core Components

### 1. Configuration System
#### Environment Variables (.env)
- **API Gateway Settings**
  - `API_GATEWAY_PORT`: Service port (default: 8080)
  - `ADMIN_SERVICE_URL`: Backend service URL

- **Rate Limiting**
  - `RATE_LIMIT_REQUESTS`: Base rate (default: 5/sec)
  - `RATE_LIMIT_BURST`: Burst allowance (default: 3)
  - `RATE_LIMIT_WINDOW`: Violation tracking window (default: 30s)
  - `MAX_RATE_LIMIT_VIOLATIONS`: Violations before ban (default: 2)

- **IP Banning**
  - `BAN_DURATION_SECONDS`: Ban duration (default: 5s)
  - `BANNED_IPS_FILE`: Ban list location

- **Logging**
  - `LOG_LEVEL`: Log verbosity
  - `LOG_BUFFER_SIZE`: Buffer size (default: 4k)
  - `LOG_FLUSH_INTERVAL`: Flush interval (default: 1s)

#### Lua Configuration Modules
Each aspect has its own configuration module under `modules/config/`:
- `admin.lua`: Admin service settings
- `ip_ban.lua`: IP banning parameters
- `rate_limit.lua`: Rate limiting rules
- `logging.lua`: Log formatting and paths
- `utils.lua`: Shared configuration utilities

### 2. Rate Limiting System
#### Core Components (modules/rate_limiter.lua)
- Uses shared dictionary for counting
- Implements token bucket algorithm
- Handles both rate and burst limits
- Thread-safe implementation

#### Violation Handling (modules/rate_limit.lua)
- Tracks violations in shared memory
- Issues 429 responses for rate limits
- Triggers IP bans after threshold
- Provides detailed error messages

### 3. IP Banning System
#### Core Functionality (modules/ip_ban.lua)
- Maintains banned IPs in shared memory
- Generates banned_ips.conf dynamically
- Auto-expires bans after duration
- Provides real-time ban status

#### Ban File Management
- Updates banned_ips.conf in real-time
- Shows ban expiration times
- Maintains nginx geo rules
- Auto-reloads nginx config

### 4. Request Processing
#### Admin Service (modules/admin.lua)
- Handles admin route requests
- Applies rate limiting rules
- Sets backend URL dynamically
- Manages proxy headers

#### Security Checks
- IP ban verification
- Rate limit validation
- Method validation
- Path validation

### 5. Logging System
#### Log Types
1. **Access Log** (/var/log/nginx/access.log)
   - Request details
   - Response times
   - Client information
   - JSON formatted

2. **Security Log** (/var/log/nginx/security.log)
   - Rate limit violations
   - Ban events
   - Security incidents
   - Violation details

3. **Error Log** (/var/log/nginx/error.log)
   - System errors
   - Configuration issues
   - Debug information

#### Log Features
- Millisecond precision timestamps
- Correlation IDs
- JSON formatting
- Buffered writing
- Automatic rotation

### 6. Testing Framework
#### Rate Limit Testing (test_rate_limit.sh)
- Tests basic rate limiting
- Verifies burst allowance
- Checks violation counting
- Validates error responses

#### Stress Testing (test_rate_limit_stress.sh)
- Rapid request testing
- Ban trigger verification
- Ban duration checking
- Auto-unban validation

## Security Features

### 1. Request Protection
- Rate limiting with burst
- Automatic IP banning
- Method validation
- Path validation
- Buffer size limits
- Timeout controls

### 2. Response Security
- Hidden server tokens
- Security headers
- XSS protection
- HSTS enabled
- Frame options
- Content security policy

### 3. System Security
- No privileged containers
- Network isolation
- Environment separation
- Minimal permissions

## Operational Notes

### 1. File Management
- banned_ips.conf is gitignored
- Logs are automatically rotated
- Configuration is environment-based
- Docker volumes for persistence

### 2. Monitoring
- JSON structured logs
- Detailed error tracking
- Security event logging
- Performance metrics

### 3. Maintenance
- Automatic ban cleanup
- Log rotation
- Configuration reloading
- Health checking

## Development Guidelines

### 1. Code Organization
- Modular Lua files
- Separate configuration
- Clear responsibilities
- Shared utilities

### 2. Configuration Management
- Use environment variables
- Validate all inputs
- Provide clear defaults
- Document all options

### 3. Testing
- Run full test suite
- Check log output
- Verify ban system
- Test rate limiting

### 4. Deployment
- Use docker-compose
- Mount required volumes
- Set environment variables
- Check logs after start

## Future Considerations
1. Add metrics collection
2. Implement caching
3. Add API key validation
4. Enhance monitoring
5. Add request validation
6. Implement circuit breaking
  