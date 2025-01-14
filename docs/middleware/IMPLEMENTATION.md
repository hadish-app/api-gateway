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
-- In registry.lua
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
-- In registry.lua
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
        local result = some_function()

        if not result then
            return false, "Operation failed"
        end

        return true
    end)

    if not ok then
        ngx.log(ngx.ERR, "Middleware error: ", err)
        return false
    end

    return true
end
```

## Testing

### Basic Test Structure

```lua
-- tests/modules/middleware/example_test.lua
local test_utils = require "tests.core.test_utils"
local example = require "modules.middleware.example"

local _M = {}

_M.tests = {
    {
        name = "Test: Basic functionality",
        func = function()
            -- Setup
            ngx.ctx = {}

            -- Execute
            local result = example:handle()

            -- Verify
            test_utils.assert_true(result)
        end
    }
}

return _M
```

### Multi-Phase Testing

```lua
-- tests/modules/middleware/multi_phase_example_test.lua
local test_utils = require "tests.core.test_utils"
local middleware = require "modules.middleware.multi_phase_example"

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
   - Use local variables
   - Cache repeated calculations

5. **Testing**:
   - Test each phase independently
   - Include error cases
   - Test state management

## Example: Complete Middleware

Here's a complete example of a rate limiting middleware:

```lua
-- modules/middleware/rate_limit.lua
local _M = {
    name = "rate_limit",
    phase = "access",
    priority = 10
}

-- Configuration
local LIMIT = 100  -- requests per minute
local WINDOW = 60  -- seconds

function _M:handle()
    local key = ngx.var.binary_remote_addr
    local time = ngx.time()
    local window = math.floor(time / WINDOW)

    -- Create window key
    local dict_key = string.format("%s:%d", key, window)

    -- Get current count
    local dict = ngx.shared.stats
    local current = dict:get(dict_key)

    if current then
        if current > LIMIT then
            ngx.log(ngx.WARN, "Rate limit exceeded for ", key)
            return ngx.exit(429)
        end

        dict:incr(dict_key, 1)
    else
        dict:set(dict_key, 1, WINDOW)
    end

    return true
end

return _M
```

This example demonstrates:

- Proper error handling
- Shared dictionary usage
- Configuration management
- Logging
- Request termination when needed

```

```
