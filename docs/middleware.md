# Middleware System

## Overview

The middleware system provides a flexible and efficient way to process HTTP requests and responses in a chain-like pattern. It supports both global middleware (applied to all routes) and route-specific middleware, with configurable execution order through priorities.

## Components

### Middleware Registry

The middleware registry (`modules/middleware/registry.lua`) manages middleware registration and initialization. It provides:

- Centralized middleware configuration
- Automatic middleware registration during startup
- State management for core middleware components

### Request Processing Middleware

The request processing middleware is organized into two main categories:

#### 1. Request Validations (`/modules/middleware/request/validations/`)

- `path_traversal_validator.lua` - Prevents path traversal attacks
- `content_validator.lua` - Validates request content
- `length_validator.lua` - Validates request length
- `method_validator.lua` - Validates HTTP methods
- `header_validator.lua` - Validates request headers

#### 2. Request Sanitizations (`/modules/middleware/request/sanitizations/`)

- `xss_protection_sanitizer.lua` - Protects against XSS attacks
- `sql_injection_sanitizer.lua` - Protects against SQL injection
- `header_sanitizer.lua` - Sanitizes request headers

### Request ID Middleware

The request ID middleware (`modules/middleware/request_id.lua`):

- Generates and tracks unique request IDs
- Preserves existing request IDs from incoming requests
- Adds request ID to response headers
- Configuration options for header names and generation behavior

## Features

- **Global & Route-specific Middleware**: Apply middleware globally or to specific routes
- **Priority-based Execution**: Control the order of middleware execution
- **State Management**: Enable/disable middleware dynamically
- **Error Handling**: Robust error propagation and logging
- **Chain Interruption**: Ability to stop the middleware chain execution
- **Debug Logging**: Comprehensive debug logging for troubleshooting

## Usage

### Using Middleware in Location Blocks

```lua
-- In your location block
location /your-endpoint {
    access_by_lua_block {
        local middleware_chain = require("modules.core.middleware_chain")

        -- Run middleware chain
        if not middleware_chain:run() then
            return  -- Chain was interrupted
        end

        -- Continue with your service logic
        -- ...
    }
}
```

### Creating Middleware

```lua
local middleware = {
    name = "my_middleware",      -- Unique identifier
    priority = 10,              -- Lower numbers run first (default: 100)
    routes = {"/api", "/admin"}, -- Empty for global middleware
    state = "disabled",         -- Initial state (default)

    handle = function(self)
        -- Your middleware logic here
        -- Return true to continue the chain
        -- Return false to stop the chain
        return true
    end
}
```

### Registering Middleware

```lua
-- In modules/middleware/registry.lua
local REGISTRY = {
    my_middleware = {
        module = "modules.middleware.my_middleware",
        state = middleware_chain.STATES.ACTIVE
    }
}
```

### Execution Order

1. Middleware is sorted by priority (lower numbers first)
2. Global middleware executes before route-specific middleware
3. Within each group, middleware executes in priority order

### State Management

```lua
-- Enable middleware
middleware_chain.set_state("my_middleware", middleware_chain.STATES.ACTIVE)

-- Disable middleware
middleware_chain.set_state("my_middleware", middleware_chain.STATES.DISABLED)
```

### Error Handling

- Errors in middleware are caught and logged
- Error details include middleware name and error message
- Chain execution stops on errors

### Debug Logging

- Middleware execution is logged at debug level
- Logs include:
  - Middleware registration
  - State changes
  - Execution order
  - Errors and chain interruptions

## Examples

### Request ID Middleware

```lua
local request_id = {
    name = "request_id",
    priority = 10,  -- Run early to ensure ID is available for logging
    routes = {},    -- Global middleware

    config = {
        header_name = "X-Request-ID",
        context_key = "request_id",
        generate_if_missing = true
    },

    handle = function(self)
        -- Get existing request ID from header
        local headers = ngx.req.get_headers()
        local request_id = headers[self.config.header_name]

        -- Generate new ID if missing and configured to do so
        if not request_id and self.config.generate_if_missing then
            request_id = uuid.generate_v4()
        end

        if request_id then
            -- Store in context and set response header
            ngx.ctx[self.config.context_key] = request_id
            ngx.header[self.config.header_name] = request_id
        end

        return true
    end
}
```

### Authentication Middleware

```lua
local auth_middleware = {
    name = "authentication",
    priority = 20,  -- Run after request ID
    routes = {"/api", "/admin"},

    handle = function(self)
        local auth_header = ngx.req.get_headers()["Authorization"]
        if not auth_header then
            ngx.status = 401
            ngx.say("Unauthorized")
            return false  -- Stop the chain
        end
        return true
    end
}
```

### Rate Limiting Middleware

```lua
local rate_limit_middleware = {
    name = "rate_limiter",
    priority = 30,
    routes = {},  -- Global middleware

    handle = function(self)
        local ip = ngx.var.remote_addr
        local limit = ngx.shared.rate_limit:get(ip)

        if limit and limit > 100 then
            ngx.status = 429
            ngx.say("Too Many Requests")
            return false
        end

        ngx.shared.rate_limit:incr(ip, 1, 0, 60)  -- 1 request, expire in 60s
        return true
    end
}
```

## Best Practices

1. **Naming**: Use descriptive names for middleware
2. **Priority**: Leave gaps between priorities (10, 20, 30...) for future middleware
3. **State Management**: Initialize middleware as disabled and enable explicitly
4. **Error Handling**: Always return true/false from handle function
5. **Logging**: Use debug logging for troubleshooting
6. **Chain Interruption**: Only stop the chain when necessary
7. **Configuration**: Use a config table for middleware settings
8. **Registration**: Prefer registry-based registration for core middleware

## Testing

The middleware system includes a comprehensive test suite covering:

- Basic middleware execution
- Priority ordering
- Route-specific middleware
- State management
- Error handling
- Chain interruption
- Request ID generation and preservation

Run tests using:

```bash
# Test specific middleware
curl http://localhost:8080/test/modules/middleware/request_id_test

# Test middleware chain
curl http://localhost:8080/test/modules/core/middleware_chain_test
```
