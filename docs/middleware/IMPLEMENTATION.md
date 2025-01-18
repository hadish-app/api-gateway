# Middleware Implementation Guide

## Overview

This guide covers how to implement middleware in the API Gateway. Middleware can be either single-phase or multi-phase, with support for route-specific behavior and priority-based execution.

## Basic Structure

### Single-Phase Middleware

```lua
-- modules/middleware/example.lua
local _M = {
    name = "example_middleware",  -- Required: Unique name
    phase = "access",            -- Required: Execution phase
    priority = 50,              -- Optional: Execution priority (default: 100)
    state = "active"            -- Optional: Initial state (default: disabled)
}

function _M:handle()
    -- Middleware logic here
    return true  -- Continue chain
end

return _M
```

### Multi-Phase Middleware

```lua
-- modules/middleware/multi_phase_example.lua
local _M = {
    name = "multi_phase_example"
}

-- Access phase handler
function _M.access:handle()
    -- Access phase logic
    return true
end

-- Header filter phase handler
function _M.header_filter:handle()
    -- Header modification logic
    return true
end

-- Log phase handler
function _M.log:handle()
    -- Logging logic
    return true
end

return _M
```

## Registration

### Single-Phase Registration

```lua
-- In middleware_registry.lua
local REGISTRY = {
    example = {
        module = "modules.middleware.example",
        state = middleware_chain.STATES.ACTIVE,
        priority = 50,
        phase = "access"
    }
}
```

### Multi-Phase Registration

```lua
-- In middleware_registry.lua
local REGISTRY = {
    multi_phase_example = {
        module = "modules.middleware.multi_phase_example",
        state = middleware_chain.STATES.ACTIVE,
        multi_phase = true,
        phases = {
            access = {
                priority = 10
            },
            header_filter = {
                priority = 20
            },
            log = {
                priority = 30
            }
        }
    }
}
```

## State Management

### Request Context

Use `ngx.ctx` for request-scoped data:

```lua
function _M:handle()
    -- Store data
    ngx.ctx.example_data = {
        timestamp = ngx.now(),
        value = "example"
    }

    -- Access data
    local data = ngx.ctx.example_data
    return true
end
```

### Error Handling

Implement proper error handling:

```lua
function _M:handle()
    local ok, err = pcall(function()
        -- Risky operation
        return process_request()
    end)

    if not ok then
        ngx.log(ngx.ERR, "Error in middleware: " .. err)
        return false
    end

    return true
end
```

## Testing

Create comprehensive tests:

```lua
-- tests/modules/middleware/example_test.lua
local test_utils = require "tests.core.test_utils"
local middleware = require "modules.middleware.example"

local _M = {}

_M.tests = {
    {
        name = "Test: Access phase",
        func = function()
            -- Setup
            ngx.ctx = {}

            -- Execute
            local result = middleware.access:handle()

            -- Verify
            test_utils.assert_true(result)
        end
    },
    {
        name = "Test: Header filter phase",
        func = function()
            -- Setup
            ngx.ctx.example_data = "test"

            -- Execute
            local result = middleware.header_filter:handle()

            -- Verify
            test_utils.assert_true(result)
            test_utils.assert_equals(ngx.header["X-Example"], "test")
        end
    }
}

return _M
```

## Best Practices

1. **Naming Conventions**:

   - Use descriptive middleware names
   - Follow Lua naming conventions
   - Keep names consistent across files

2. **Phase Selection**:

   - Choose appropriate phases for operations
   - Consider dependencies between phases
   - Use multi-phase when necessary

3. **Error Handling**:

   - Always use pcall for risky operations
   - Log errors with context
   - Return false to stop chain on errors

4. **Performance**:

   - Minimize shared dictionary access
   - Cache frequently used values
   - Avoid unnecessary string operations

5. **Configuration**:

   - Use configuration tables
   - Support runtime updates
   - Validate configuration values

6. **Testing**:

   - Write unit tests for each phase
   - Test error conditions
   - Mock external dependencies

7. **Documentation**:

   - Document configuration options
   - Explain phase dependencies
   - Provide usage examples

8. **Logging**:

   - Use appropriate log levels
   - Include request context
   - Log performance metrics

## Example Implementation

Here's a complete example:

```lua
-- modules/middleware/example.lua
local _M = {
    name = "example",
    phase = "access",
    priority = 50,
    state = "active",
    config = {
        timeout = 1000,
        max_retries = 3
    }
}

function _M:handle()
    -- Get request context
    local ctx = {
        client = ngx.var.remote_addr,
        method = ngx.req.get_method(),
        uri = ngx.var.request_uri
    }

    -- Log entry
    ngx.log(ngx.DEBUG, string.format("[%s] Processing request from %s: %s %s",
        self.name, ctx.client, ctx.method, ctx.uri))

    -- Process with error handling
    local ok, err = pcall(function()
        -- Implementation
        return process_request(ctx)
    end)

    if not ok then
        ngx.log(ngx.ERR, string.format("[%s] Error: %s", self.name, err))
        return false
    end

    return true
end

return _M
```

```

```
