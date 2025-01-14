# NGINX Configuration Guide

## Overview

This guide explains our NGINX configuration for the API Gateway. It's designed to be beginner-friendly while covering all essential aspects of our setup.

## Configuration Structure

Our NGINX configuration follows a modular approach, breaking down complex configurations into manageable, purpose-specific files:

```
configs/
├── core/                  # Core configurations
│   ├── env.conf          # Environment variables
│   ├── basic.conf        # Basic NGINX settings
│   ├── error_log.conf    # Error logging settings
│   ├── debug_log.conf    # Debug logging settings
│   └── access_log.conf   # Access logging settings
│
├── lua/                  # Lua-specific configurations
│   ├── paths.conf        # Lua module paths
│   └── dict.conf         # Shared dictionaries
│
├── locations/            # Location blocks
│   ├── default.conf      # Default location handler
│   ├── health.conf       # Health check endpoint
│   └── test.conf        # Test endpoints
│
└── nginx.conf           # Main configuration file
```

### Why This Structure?

1. **Modularity**: Each file has a single responsibility, making configurations easier to understand and maintain
2. **Reusability**: Common configurations can be reused across different server blocks
3. **Maintainability**: Easier to update specific aspects without touching the entire configuration
4. **Clarity**: Clear separation of concerns helps new developers understand the system

## Main Configuration (`nginx.conf`)

```nginx
# Core Configuration
include core/env.conf;        # Environment variables
include core/basic.conf;      # Basic nginx settings

# Logging Configuration
include core/error_log.conf;  # Error level logging
include core/debug_log.conf;  # Debug level logging

# HTTP Configuration
http {
    # Core HTTP Settings
    include core/access_log.conf;     # HTTP access logging

    # Lua Configuration
    include lua/paths.conf;           # Lua module paths
    include lua/dict.conf;            # Shared dictionaries

    # Phase Initialization
    init_by_lua_block {
        require("core.phase_handlers").init()
    }

    init_worker_by_lua_block {
        require("core.phase_handlers").init_worker()
    }

    # Server Configuration
    server {
        listen 80;
        server_name localhost;

        # Core Location Handlers
        include locations/default.conf;    # Default handler
        include locations/health.conf;     # Health checks
        include locations/test.conf;       # Integration tests
    }
}
```

### Understanding Each Section

#### 1. Core Configuration

```nginx
include core/env.conf;        # Environment variables
include core/basic.conf;      # Basic nginx settings
```

**What**: Basic NGINX settings and environment variables
**Why**:

- Separates core settings from application logic
- Makes environment configuration flexible
- Easier to maintain different environments (dev/prod)

#### 2. Logging Configuration

```nginx
include core/error_log.conf;  # Error level logging
include core/debug_log.conf;  # Debug level logging
include core/access_log.conf; # HTTP access logging
```

**What**: Different types of logging configurations
**Why**:

- Separates different log types for better debugging
- Allows different log formats for different purposes
- Makes log management easier

#### 3. Lua Configuration

```nginx
include lua/paths.conf;       # Lua module paths
include lua/dict.conf;       # Shared dictionaries
```

**What**: Lua-specific settings and shared memory
**Why**:

- Keeps Lua configurations separate
- Makes memory management clear
- Easier to adjust Lua settings

#### 4. Phase Initialization

```nginx
init_by_lua_block {
    require("core.phase_handlers").init()
}

init_worker_by_lua_block {
    require("core.phase_handlers").init_worker()
}
```

**What**: Initializes Lua modules and worker processes
**Why**:

- Proper initialization of Lua modules
- Worker-specific setup
- Clean separation of initialization logic

## Location Configurations

### Default Location (`locations/default.conf`)

```nginx
location / {
    default_type application/json;
    content_by_lua_block {
        require("core.phase_handlers").handle_request()
    }
}
```

**What**: Handles all unmatched requests
**Why**:

- Provides a catch-all handler
- Ensures consistent JSON responses
- Routes requests through our Lua handler

### Health Check (`locations/health.conf`)

```nginx
location = /health {
    default_type application/json;
    content_by_lua_block {
        require("modules.services.health").handle()
    }
}
```

**What**: Health check endpoint
**Why**:

- Monitoring system health
- Load balancer checks
- Kubernetes readiness/liveness probes

### Test Endpoints (`locations/test.conf`)

```nginx
location /tests {
    default_type application/json;
    content_by_lua_block {
        require("core.test_runner").handle()
    }
}
```

**What**: Integration test endpoints
**Why**:

- Easy test execution
- Isolated test environment
- Convenient for CI/CD

## Common Configurations

### Environment Variables (`core/env.conf`)

```nginx
# Server Configuration
env SERVER_PORT;
env SERVER_WORKER_PROCESSES;
env SERVER_WORKER_CONNECTIONS;
```

**What**: Declares environment variables
**Why**:

- Configuration through environment
- No hardcoded values
- Easy deployment to different environments

### Lua Paths (`lua/paths.conf`)

```nginx
lua_package_path '/path/to/lua/?.lua;;';
lua_code_cache on;
```

**What**: Configures Lua module loading
**Why**:

- Proper module resolution
- Code caching for performance
- Clear module organization

### Shared Dictionaries (`lua/dict.conf`)

```nginx
lua_shared_dict stats 10m;
lua_shared_dict cache 10m;
```

**What**: Shared memory spaces
**Why**:

- Inter-worker communication
- Shared state management
- Performance optimization

## Best Practices

1. **Configuration Organization**:

   - Keep related configurations together
   - Use clear, descriptive file names
   - Comment complex configurations
   - Use includes for modularity

2. **Environment Variables**:

   - Use environment variables for configuration
   - Declare all variables in `env.conf`
   - Document variable usage
   - Provide default values

3. **Logging**:

   - Use appropriate log levels
   - Configure log rotation
   - Include request IDs
   - Use structured logging

4. **Performance**:

   - Enable code caching in production
   - Configure worker processes appropriately
   - Use shared dictionaries wisely
   - Monitor resource usage

5. **Security**:
   - Disable unnecessary modules
   - Use secure defaults
   - Configure SSL properly
   - Implement rate limiting

## Common Tasks

### 1. Adding a New Location

1. Create a new file in `configs/locations/`
2. Define the location block
3. Include it in `nginx.conf`

Example:

```nginx
# configs/locations/api.conf
location /api {
    default_type application/json;
    content_by_lua_block {
        require("modules.api").handle()
    }
}
```

### 2. Modifying Log Formats

1. Edit `configs/core/access_log.conf`
2. Define new log format
3. Add new access_log directive

### 3. Adding Shared Dictionary

1. Edit `configs/lua/dict.conf`
2. Add new lua_shared_dict directive
3. Update documentation

## Troubleshooting

1. **Configuration Testing**:

   ```bash
   nginx -t
   ```

2. **Viewing Logs**:

   ```bash
   tail -f logs/error.log
   tail -f logs/access.log
   ```

3. **Reloading Configuration**:
   ```bash
   nginx -s reload
   ```

## Further Reading

1. [NGINX Documentation](http://nginx.org/en/docs/)
2. [OpenResty Documentation](https://openresty.org/en/getting-started.html)
3. [Lua NGINX Module](https://github.com/openresty/lua-nginx-module)

```

```
