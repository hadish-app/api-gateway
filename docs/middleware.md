# Middleware System

## Overview

The API Gateway implements a hybrid middleware system that leverages both OpenResty's request processing phases and a flexible middleware chain. This approach combines the benefits of OpenResty's phase-based processing with the flexibility of middleware patterns.

## Architecture

### Phase Handlers

The core of our system is the phase handler (`modules/core/phase_handlers.lua`) which:

- Manages OpenResty's request processing phases
- Initializes shared dictionaries
- Coordinates middleware execution
- Handles shared state

```lua
-- Phase handlers example
local function verify_shared_dicts()
    -- Verify required shared dictionaries are available
    for _, dict_name in ipairs(SHARED_DICTS.required) do
        if not shared[dict_name] then
            log(ERR, "Required shared dictionary not found: " .. dict_name)
            return false
        end
    end
    return true
end
```

### Middleware Registry

The middleware registry (`modules/middleware/registry.lua`) manages middleware registration and initialization. It provides:

- Centralized middleware configuration
- Phase-specific middleware management
- Priority-based execution order
- Multi-phase middleware support

```lua
-- Registry configuration example
local REGISTRY = {
    request_id = {
        module = "modules.middleware.request_id",
        state = middleware_chain.STATES.ACTIVE,
        multi_phase = true,
        phases = {
            access = {
                priority = 10
            },
            header_filter = {
                priority = 10
            },
            log = {
                priority = 10
            }
        }
    }
}
```

### Valid Phases

The system supports the following phases for middleware execution:

```lua
local PHASES = {
    access = true,
    content = true,
    header_filter = true,
    body_filter = true,
    log = true
}
```

## Middleware Implementation

### Single-Phase Middleware

For middleware that operates in a single phase:

```lua
local middleware = {
    name = "example",
    phase = "access",
    state = middleware_chain.STATES.ACTIVE,
    handle = function(self)
        -- Middleware logic here
        return true
    end
}
```

### Multi-Phase Middleware

For middleware that needs to operate across multiple phases:

```lua
-- In middleware file
return {
    access = {
        name = "example_access",
        phase = "access",
        handle = function(self)
            -- Access phase logic
            return true
        end
    },
    header_filter = {
        name = "example_header_filter",
        phase = "header_filter",
        handle = function(self)
            -- Header filter phase logic
            return true
        end
    }
}

-- In registry
{
    example = {
        module = "modules.middleware.example",
        state = middleware_chain.STATES.ACTIVE,
        multi_phase = true,
        phases = {
            access = { priority = 10 },
            header_filter = { priority = 20 }
        }
    }
}
```

## State Management

### Shared Dictionaries

The system uses several shared dictionaries for state management:

- `stats`: Runtime statistics
- `metrics`: Performance metrics
- `config_cache`: Configuration cache
- `rate_limit`: Rate limiting data
- `ip_blacklist`: IP blocking list
- `worker_events`: Worker communication

### Request Context

Middleware can share data within a request using:

```lua
-- Using ngx.ctx for request-scoped data
function access_phase(self)
    ngx.ctx.request_start = ngx.now()
end

function log_phase(self)
    local duration = ngx.now() - ngx.ctx.request_start
    ngx.log(ngx.INFO, "Request duration: ", duration)
end
```

## Best Practices

1. **Phase Selection**:

   - Use appropriate phases for specific operations
   - Consider operation timing and dependencies
   - Leverage phase characteristics

2. **State Management**:

   - Use `ngx.ctx` for request-scoped data
   - Use shared dictionaries for worker-level data
   - Clear state appropriately

3. **Error Handling**:

   - Return `false` and error message for recoverable errors
   - Use `ngx.exit()` for immediate termination
   - Log errors appropriately

4. **Performance**:
   - Set appropriate priorities for execution order
   - Minimize shared dictionary operations
   - Use local caching when possible

## Example: Request ID Middleware

The request ID middleware demonstrates best practices:

```lua
-- In modules/middleware/request_id.lua
local _M = {}

_M.access = {
    name = "request_id_access",
    phase = "access",
    handle = function(self)
        -- Generate or extract request ID
        local request_id = ngx.req.get_headers()["X-Request-ID"]
        if not request_id then
            request_id = generate_uuid()
        end
        ngx.ctx.request_id = request_id
        return true
    end
}

_M.header_filter = {
    name = "request_id_header_filter",
    phase = "header_filter",
    handle = function(self)
        -- Set response header
        ngx.header["X-Request-ID"] = ngx.ctx.request_id
        return true
    end
}

_M.log = {
    name = "request_id_log",
    phase = "log",
    handle = function(self)
        -- Log request completion
        ngx.log(ngx.INFO, "Request completed: ", ngx.ctx.request_id)
        return true
    end
}

return _M
```

## Testing

Middleware tests should:

- Test each phase independently
- Verify phase interactions
- Test state management
- Validate error handling

See `tests/modules/middleware/` for examples.
