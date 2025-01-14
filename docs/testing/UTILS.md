# Test Utilities

## Overview

The test utilities module provides a set of helper functions and assertions for testing the API Gateway components. This guide covers the available utilities and their usage.

## Core Utilities

```lua
-- tests/test_utils.lua
local _M = {}

-- Assertion functions
function _M.assert_equals(actual, expected, message)
    assert(actual == expected,
           message or string.format("Expected %s but got %s",
                                  tostring(expected),
                                  tostring(actual)))
end

function _M.assert_not_equals(actual, expected, message)
    assert(actual ~= expected,
           message or string.format("Expected value different from %s",
                                  tostring(expected)))
end

function _M.assert_true(value, message)
    assert(value == true,
           message or "Expected true value")
end

function _M.assert_false(value, message)
    assert(value == false,
           message or "Expected false value")
end

function _M.assert_nil(value, message)
    assert(value == nil,
           message or "Expected nil value")
end

function _M.assert_not_nil(value, message)
    assert(value ~= nil,
           message or "Expected non-nil value")
end

function _M.assert_type(value, expected_type, message)
    assert(type(value) == expected_type,
           message or string.format("Expected type %s but got %s",
                                  expected_type,
                                  type(value)))
end

function _M.assert_error(func, message)
    local ok, err = pcall(func)
    assert(not ok,
           message or "Expected function to raise an error")
    return err
end
```

## Mock Utilities

### Request Mocking

```lua
-- Mock request context
function _M.mock_request(options)
    options = options or {}

    ngx.ctx = {}
    ngx.var = {
        request_method = options.method or "GET",
        uri = options.uri or "/",
        remote_addr = options.remote_addr or "127.0.0.1",
        host = options.host or "localhost"
    }

    ngx.req.get_headers = function()
        return options.headers or {}
    end

    ngx.req.get_method = function()
        return options.method or "GET"
    end
end

-- Example usage
test_utils.mock_request({
    method = "POST",
    uri = "/api/users",
    headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer token"
    }
})
```

### Response Mocking

```lua
-- Mock response context
function _M.mock_response()
    ngx.status = 200
    ngx.header = {}
    ngx.ctx.response_body = nil

    -- Mock response functions
    ngx.say = function(...)
        local args = {...}
        ngx.ctx.response_body = table.concat(args)
    end

    ngx.exit = function(status)
        ngx.status = status
        return status
    end
end

-- Example usage
test_utils.mock_response()
ngx.say("Hello")
assert(ngx.ctx.response_body == "Hello")
```

### Shared Dictionary Mocking

```lua
-- Mock shared dictionary
function _M.mock_dict(name)
    local dict = {}
    local data = {}

    dict.get = function(_, key)
        return data[key]
    end

    dict.set = function(_, key, value)
        data[key] = value
        return true
    end

    dict.incr = function(_, key, value)
        data[key] = (data[key] or 0) + value
        return data[key]
    end

    dict.flush_all = function()
        for k in pairs(data) do
            data[k] = nil
        end
    end

    ngx.shared[name] = dict
    return dict
end

-- Example usage
local stats = test_utils.mock_dict("stats")
stats:set("counter", 1)
assert(stats:get("counter") == 1)
```

## State Management

### Test State Reset

```lua
-- Reset test state
function _M.reset_state()
    -- Reset request context
    ngx.ctx = {}

    -- Reset response state
    ngx.status = 200
    ngx.header = {}

    -- Reset shared dictionaries
    for name, dict in pairs(ngx.shared) do
        dict:flush_all()
    end
end

-- Example usage
local function test_case()
    test_utils.reset_state()
    -- Test implementation
end
```

### Timer Mocking

```lua
-- Mock timer utilities
function _M.mock_timer()
    local timers = {}

    ngx.timer.at = function(delay, func, ...)
        local timer = {
            delay = delay,
            func = func,
            args = {...}
        }
        table.insert(timers, timer)
        return true
    end

    return {
        run = function()
            for _, timer in ipairs(timers) do
                timer.func(unpack(timer.args))
            end
        end,
        count = function()
            return #timers
        end
    }
end

-- Example usage
local timer = test_utils.mock_timer()
ngx.timer.at(0, function() print("Timer executed") end)
assert(timer.count() == 1)
timer.run()
```

## Helper Functions

### Table Utilities

```lua
-- Deep table comparison
function _M.tables_equal(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return t1 == t2
    end

    for k, v in pairs(t1) do
        if not _M.tables_equal(v, t2[k]) then
            return false
        end
    end

    for k, v in pairs(t2) do
        if not _M.tables_equal(v, t1[k]) then
            return false
        end
    end

    return true
end

-- Table assertions
function _M.assert_tables_equal(actual, expected, message)
    assert(_M.tables_equal(actual, expected),
           message or "Tables are not equal")
end
```

### UUID Validation

```lua
-- UUID validation
function _M.is_valid_uuid(str)
    local pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    return type(str) == "string" and string.match(str:lower(), pattern) ~= nil
end

-- UUID assertion
function _M.assert_valid_uuid(value, message)
    assert(_M.is_valid_uuid(value),
           message or "Expected valid UUID")
end
```

## Usage Examples

### Complete Test Case

```lua
-- Example test using multiple utilities
local test_utils = require "tests.test_utils"
local middleware = require "modules.middleware.example"

local _M = {}

_M.tests = {
    {
        name = "Test: Complete middleware flow",
        func = function()
            -- Setup
            test_utils.reset_state()
            test_utils.mock_request({
                method = "POST",
                uri = "/api/users",
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            test_utils.mock_response()
            local stats = test_utils.mock_dict("stats")

            -- Execute
            local result = middleware:handle()

            -- Verify
            test_utils.assert_true(result)
            test_utils.assert_equals(ngx.status, 200)
            test_utils.assert_not_nil(ngx.ctx.request_id)
            test_utils.assert_valid_uuid(ngx.ctx.request_id)
            test_utils.assert_equals(stats:get("requests"), 1)
        end
    }
}

return _M
```

```

```
