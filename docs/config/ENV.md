# Environment Configuration

## Overview

The API Gateway uses a structured environment configuration system that organizes variables into logical sections and provides automatic type inference. This guide covers the environment configuration system, including variable naming conventions, configuration loading, and usage.

## Environment Structure

### Naming Convention

Environment variables follow a section-based naming pattern:

```bash
SECTION_KEY_SUBKEY=value
```

The name is automatically parsed into a section and key:

- Converted to lowercase
- First underscore-separated part becomes the section
- Remaining parts become the key (keeping underscores)

For example:

- `SERVER_PORT=8080` → `config.server.port`
- `LOGGING_ACCESS_LOG=true` → `config.logging.access_log`
- `SECURITY_RATE_LIMIT_REQUESTS=100` → `config.security.rate_limit_requests`

### Type Inference

The system automatically infers types from string values:

```lua
-- Boolean values
"true", "1", "yes" → true
"false", "0", "no" → false

-- Numeric values
"123" → 123 (number)

-- Special cases
"" → nil
other → string (as is)
```

### Value Resolution

Environment values are resolved in the following order:

1. `ngx.env` (from `env.conf`)
2. `os.getenv` (from system environment)

This allows for flexible configuration through both Nginx and system environment variables.

## Configuration Files

### 1. Environment Variables (`.env`)

Core configuration file containing all environment variables and their default values:

```bash
# Server Configuration
SERVER_PORT=8080
SERVER_WORKER_PROCESSES=auto
SERVER_WORKER_CONNECTIONS=1024
SERVER_KEEPALIVE=75

# ... other sections ...
```

### 2. Nginx Environment Declaration (`configs/core/env.conf`)

Declares which environment variables are accessible through `ngx.env`:

```nginx
# Server Configuration
env SERVER_PORT;
env SERVER_WORKER_PROCESSES;
# ... other declarations ...
```

### 3. Environment Utility (`modules/utils/env.lua`)

Handles environment variable loading and processing:

```lua
-- Load all environment variables
function _M.load_all()
    local config = {}
    local env_vars = list_env_vars()

    for name, value in pairs(env_vars) do
        local section, key = parse_env_name(name)
        if section and key then
            local converted = infer_and_convert(value)
            if converted ~= nil then
                config[section] = config[section] or {}
                config[section][key] = converted

                log(INFO, string.format("Loaded env var %s as %s.%s = %s",
                    name, section, key, tostring(converted)))
            end
        end
    end

    return config
end
```

## Environment Variables Reference

### Server Configuration

| Variable                  | Type   | Default | Description                  | Required |
| ------------------------- | ------ | ------- | ---------------------------- | -------- |
| SERVER_PORT               | number | 8080    | HTTP server port             | Yes      |
| SERVER_WORKER_PROCESSES   | string | "auto"  | Number of worker processes   | Yes      |
| SERVER_WORKER_CONNECTIONS | number | 1024    | Max connections per worker   | Yes      |
| SERVER_KEEPALIVE          | number | 75      | Keepalive timeout in seconds | Yes      |

### System Configuration

| Variable                | Type   | Default | Description                 | Required |
| ----------------------- | ------ | ------- | --------------------------- | -------- |
| SYSTEM_CLEANUP_INTERVAL | number | 10      | Cleanup interval in seconds | Yes      |

### Logging Configuration

| Variable               | Type    | Default  | Description           | Required |
| ---------------------- | ------- | -------- | --------------------- | -------- |
| LOGGING_LEVEL          | string  | "notice" | Log level             | Yes      |
| LOGGING_BUFFER_SIZE    | string  | "4k"     | Log buffer size       | Yes      |
| LOGGING_FLUSH_INTERVAL | string  | "1s"     | Log flush interval    | Yes      |
| LOGGING_ACCESS_LOG     | boolean | true     | Enable access logging | Yes      |
| LOGGING_ERROR_LOG      | boolean | true     | Enable error logging  | Yes      |

### Security Configuration

| Variable                     | Type    | Default           | Description             | Required |
| ---------------------------- | ------- | ----------------- | ----------------------- | -------- |
| SECURITY_RATE_LIMIT_REQUESTS | number  | 100               | Requests per window     | Yes      |
| SECURITY_RATE_LIMIT_WINDOW   | number  | 60                | Window size in seconds  | Yes      |
| SECURITY_RATE_LIMIT_BURST    | number  | 120               | Burst size              | Yes      |
| SECURITY_IP_BAN_MAX_FAILS    | number  | 10                | Max failures before ban | Yes      |
| SECURITY_IP_BAN_DURATION     | number  | 3600              | Ban duration in seconds | Yes      |
| SECURITY_SSL_ENABLED         | boolean | true              | Enable SSL/TLS          | Yes      |
| SECURITY_SSL_PROTOCOLS       | string  | "TLSv1.2 TLSv1.3" | Allowed SSL protocols   | Yes      |

### Cache Configuration

| Variable          | Type    | Default | Description             | Required |
| ----------------- | ------- | ------- | ----------------------- | -------- |
| CACHE_ENABLED     | boolean | true    | Enable caching          | Yes      |
| CACHE_DEFAULT_TTL | number  | 3600    | Default TTL in seconds  | Yes      |
| CACHE_MAX_SIZE    | string  | "10m"   | Maximum cache size      | Yes      |
| CACHE_MIN_USES    | number  | 2       | Min uses before caching | Yes      |

### Proxy Configuration

| Variable              | Type   | Default | Description                | Required |
| --------------------- | ------ | ------- | -------------------------- | -------- |
| PROXY_READ_TIMEOUT    | number | 60      | Read timeout in seconds    | Yes      |
| PROXY_SEND_TIMEOUT    | number | 60      | Send timeout in seconds    | Yes      |
| PROXY_CONNECT_TIMEOUT | number | 60      | Connect timeout in seconds | Yes      |
| PROXY_BUFFER_SIZE     | string | "4k"    | Proxy buffer size          | Yes      |
| PROXY_BUFFERS         | string | "8 4k"  | Proxy buffers config       | Yes      |

### Monitoring Configuration

| Variable                         | Type    | Default | Description               | Required |
| -------------------------------- | ------- | ------- | ------------------------- | -------- |
| MONITORING_ENABLED               | boolean | true    | Enable monitoring         | Yes      |
| MONITORING_METRICS_ENABLED       | boolean | true    | Enable metrics collection | Yes      |
| MONITORING_HEALTH_CHECK_INTERVAL | number  | 5       | Check interval in seconds | Yes      |
| MONITORING_HEALTH_CHECK_TIMEOUT  | number  | 3       | Check timeout in seconds  | Yes      |

### CORS Configuration

| Variable               | Type    | Default                           | Description              | Required |
| ---------------------- | ------- | --------------------------------- | ------------------------ | -------- |
| CORS_ENABLED           | boolean | true                              | Enable CORS              | Yes      |
| CORS_ALLOW_ORIGINS     | string  | "\*"                              | Allowed origins          | Yes      |
| CORS_ALLOW_METHODS     | string  | "GET, POST, PUT, DELETE, OPTIONS" | Allowed HTTP methods     | Yes      |
| CORS_ALLOW_HEADERS     | string  | "Content-Type, Authorization"     | Allowed headers          | Yes      |
| CORS_ALLOW_CREDENTIALS | boolean | true                              | Allow credentials        | Yes      |
| CORS_MAX_AGE           | number  | 86400                             | Preflight cache duration | Yes      |

## Best Practices

1. **Configuration Management**:

   - Use `.env.example` as a template
   - Never commit `.env` to version control
   - Document all changes to environment variables
   - Keep defaults in sync between files

2. **Value Types**:

   - Use appropriate data types
   - Set sensible defaults
   - Document units (e.g., seconds, bytes)
   - Use standard formats

3. **Security**:

   - Never commit sensitive values
   - Use secure defaults
   - Validate required variables
   - Document security implications

4. **Implementation**:

   - Always declare variables in `env.conf`
   - Use `ngx.env` over `os.getenv` when possible
   - Log configuration loading
   - Handle missing values gracefully

5. **Documentation**:
   - Keep this reference updated
   - Document all sections
   - Include examples
   - Explain relationships between variables

## Usage Examples

### Loading Configuration

```lua
-- Load environment configuration
local env = require "modules.utils.env"
local config = env.load_all()

-- Access configuration values
local server_port = config.server.port
local is_logging_enabled = config.logging.access_log

-- Use in middleware
if config.security.ssl_enabled then
    -- SSL handling
end
```

### Error Handling

```lua
-- Example of handling missing required values
local function validate_config(config)
    local required = {
        {"server", "port"},
        {"logging", "level"},
        {"security", "ssl_enabled"}
    }

    for _, path in ipairs(required) do
        local section, key = unpack(path)
        if not config[section] or config[section][key] == nil then
            return nil, string.format("Missing required config: %s.%s",
                section, key)
        end
    end

    return true
end
```

```

```
