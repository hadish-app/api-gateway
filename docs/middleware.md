# Middleware System

## Overview

The middleware system provides a flexible and efficient way to process HTTP requests and responses in a chain-like pattern. It supports both global middleware (applied to all routes) and route-specific middleware, with configurable execution order through priorities.

## Features

- **Global & Route-specific Middleware**: Apply middleware globally or to specific routes
- **Priority-based Execution**: Control the order of middleware execution
- **State Management**: Enable/disable middleware dynamically
- **Error Handling**: Robust error propagation and logging
- **Chain Interruption**: Ability to stop the middleware chain execution
- **Debug Logging**: Comprehensive debug logging for troubleshooting

## Usage

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
local middleware_chain = require "modules.core.middleware_chain"

-- Add middleware to the chain
middleware_chain.use(middleware, "my_middleware")

-- Enable the middleware
middleware_chain.set_state("my_middleware", middleware_chain.STATES.ACTIVE)
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

### Authentication Middleware

```lua
local auth_middleware = {
    name = "authentication",
    priority = 10,  -- Run early in the chain
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
    priority = 20,
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

## Testing

The middleware system includes a comprehensive test suite covering:

- Basic middleware execution
- Priority ordering
- Route-specific middleware
- State management
- Error handling
- Chain interruption

Run tests using:

```bash
curl http://localhost:8080/test/modules/core/middleware_chain_test
```
