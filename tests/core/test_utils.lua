--- Test utilities module
-- @module tests.core.test_utils
-- @description Common utilities and assertions for tests

local cjson = require "cjson"

local _M = {}

-- Store original functions
local original_ngx_status
local original_ngx_exit
local mock_status = 200

-- Mock state tracking
local mock_headers = {}
local mock_method = "GET"
local mock_uri = "/"
local mock_uri_args = {}
local mock_post_args = {}
local mock_body = ""

_M = {
    last_exit_code = nil,  -- Track the last exit code called
    -- Add mock configuration functions
    mock = {
        set_headers = function(headers)
            ngx.log(ngx.DEBUG, "[MOCK] Setting request headers: " .. cjson.encode(headers))
            mock_headers = headers
        end,
        set_method = function(method)
            ngx.log(ngx.DEBUG, "[MOCK] Setting request method: " .. method)
            mock_method = method
        end,
        set_uri = function(uri)
            ngx.log(ngx.DEBUG, "[MOCK] Setting request URI: " .. uri)
            mock_uri = uri
        end,
        set_uri_args = function(args)
            ngx.log(ngx.DEBUG, "[MOCK] Setting URI args: " .. cjson.encode(args))
            mock_uri_args = args
        end,
        set_post_args = function(args)
            ngx.log(ngx.DEBUG, "[MOCK] Setting POST args: " .. cjson.encode(args))
            mock_post_args = args
        end,
        set_body = function(body)
            ngx.log(ngx.DEBUG, "[MOCK] Setting request body: " .. body)
            mock_body = body
        end
    }
}

-- Mock ngx.status with a getter/setter
local status_mock = {
    __index = function(_, key)
        if key == "status" then
            return mock_status
        end
        return original_ngx_status and original_ngx_status[key]
    end,
    __newindex = function(_, key, value)
        if key == "status" then
            mock_status = value
            return
        end
        if original_ngx_status then
            original_ngx_status[key] = value
        end
    end
}

-- Constants
_M.COLORS = {
    RED = "\27[31m",
    GREEN = "\27[32m",
    YELLOW = "\27[33m",
    RESET = "\27[0m"
}

-- Setup and teardown ngx mocks
function _M.setup_mocks()
    ngx.log(ngx.DEBUG, "[MOCK] Setting up ngx mocks")
    
    -- Setup status mock
    ngx.log(ngx.DEBUG, "[MOCK] Setting up ngx.status mock")
    original_ngx_status = getmetatable(ngx)
    setmetatable(ngx, status_mock)
    
    -- Setup exit mock
    ngx.log(ngx.DEBUG, "[MOCK] Setting up ngx.exit mock")
    original_ngx_exit = ngx.exit
    ngx.exit = function(status)
        ngx.log(ngx.DEBUG, "[MOCK] ngx.exit called with status: " .. tostring(status))
        _M.last_exit_code = status
        mock_status = status
        error("ngx.exit(" .. status .. ")", 0)
    end
    
    -- Setup request mocks
    ngx.log(ngx.DEBUG, "[MOCK] Setting up ngx.req mocks")
    ngx.req.get_headers = function()
        ngx.log(ngx.DEBUG, "[MOCK] Getting request headers: " .. cjson.encode(mock_headers))
        return mock_headers
    end
    
    ngx.req.get_method = function()
        ngx.log(ngx.DEBUG, "[MOCK] Getting request method: " .. mock_method)
        return mock_method
    end
    
    ngx.req.get_uri_args = function()
        ngx.log(ngx.DEBUG, "[MOCK] Getting URI args: " .. cjson.encode(mock_uri_args))
        return mock_uri_args
    end
    
    ngx.req.get_post_args = function()
        ngx.log(ngx.DEBUG, "[MOCK] Getting POST args: " .. cjson.encode(mock_post_args))
        return mock_post_args
    end
    
    ngx.req.read_body = function()
        ngx.log(ngx.DEBUG, "[MOCK] Reading request body")
        -- No-op as we're mocking
    end
    
    ngx.req.get_body_data = function()
        ngx.log(ngx.DEBUG, "[MOCK] Getting request body: " .. mock_body)
        return mock_body
    end
    
    ngx.log(ngx.DEBUG, "[MOCK] All mocks setup completed")
end

function _M.teardown_mocks()
    ngx.log(ngx.DEBUG, "[MOCK] Tearing down ngx mocks")
    
    -- Restore status mock
    if original_ngx_status then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.status: " .. tostring(original_ngx_status))
        setmetatable(ngx, original_ngx_status)
    end
    
    -- Restore exit mock
    if original_ngx_exit then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.exit")
        ngx.exit = original_ngx_exit
    end
    
    -- Reset tracking
    _M.last_exit_code = nil
    
    ngx.log(ngx.DEBUG, "[MOCK] All mocks teardown completed")
end

-- State management
function _M.reset_state()
    ngx.log(ngx.DEBUG, "[STATE] Resetting state")
    ngx.log(ngx.DEBUG, "[STATE] Previous state - " ..
        "ngx.status=" .. tostring(mock_status) .. 
        ", last_exit_code=" .. tostring(_M.last_exit_code) ..
        ", method=" .. tostring(mock_method) ..
        ", headers=" .. cjson.encode(mock_headers) ..
        ", uri=" .. tostring(mock_uri) ..
        ", uri_args=" .. cjson.encode(mock_uri_args) ..
        ", post_args=" .. cjson.encode(mock_post_args) ..
        ", body=" .. tostring(mock_body) ..
        ", ctx=" .. cjson.encode(ngx.ctx) .. 
        ", response_headers=" .. cjson.encode(ngx.header))
    
    -- Reset all mock states
    mock_headers = {}
    mock_method = "GET"
    mock_uri = "/"
    mock_uri_args = {}
    mock_post_args = {}
    mock_body = ""
    mock_status = 200
    _M.last_exit_code = nil
    ngx.ctx = {}
    ngx.header = {}
    
    if ngx.shared then
        for dict_name, dict in pairs(ngx.shared) do
            dict:flush_all()
            ngx.log(ngx.DEBUG, "[STATE] Flushed shared dict: " .. dict_name)
        end
    end
    
    ngx.log(ngx.DEBUG, "[STATE] State reset completed")
end

-- Core assertions
function _M.assert_equals(expected, actual, message)
    if expected == actual then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected: " .. tostring(expected))
        ngx.say("  Got: " .. tostring(actual))
        return false
    end
end

function _M.assert_not_equals(expected, actual, message)
    if expected ~= actual then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected not to equal: " .. tostring(expected))
        ngx.say("  Got: " .. tostring(actual))
        return false
    end
end

function _M.assert_not_nil(value, message)
    if value ~= nil then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected value to not be nil")
        return false
    end
end

function _M.assert_nil(value, message)
    if value == nil then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected nil but got: " .. tostring(value))
        return false
    end
end

function _M.assert_true(value, message)
    if value == true then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected true but got: " .. tostring(value))
        return false
    end
end

function _M.assert_false(value, message)
    if value == false then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected false but got: " .. tostring(value))
        return false
    end
end

-- Type assertions
function _M.assert_type(value, expected_type, message)
    if type(value) == expected_type then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected type: " .. expected_type)
        ngx.say("  Got type: " .. type(value))
        return false
    end
end

-- Table assertions
function _M.assert_table_equals(expected, actual, message)
    local json_expected = cjson.encode(expected)
    local json_actual = cjson.encode(actual)
    
    if json_expected == json_actual then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected: " .. json_expected)
        ngx.say("  Got: " .. json_actual)
        return false
    end
end

-- String pattern matching assertion
function _M.assert_matches(value, pattern, message)
    if type(value) ~= "string" then
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected a string but got: " .. type(value))
        return false
    end
    
    if string.match(value, pattern) then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected string matching pattern: " .. pattern)
        ngx.say("  Got: " .. value)
        return false
    end
end

-- Test suite runner
function _M.run_suite(test_path, tests, before_all, before_each, after_each, after_all)
    ngx.log(ngx.DEBUG, "=== Starting test suite: " .. test_path .. " ===")
    
    -- Setup mocks before running tests
    _M.setup_mocks()
    
    local total = 0
    local passed = 0
    local failed = 0
    
    -- Run before_all if available
    if before_all then
        ngx.log(ngx.DEBUG, "[LIFECYCLE] Executing before_all")
        local ok, err = pcall(before_all)
        if not ok then
            ngx.log(ngx.ERR, "[LIFECYCLE] before_all failed: " .. tostring(err))
            ngx.say(_M.COLORS.RED .. "Error in before_all: " .. err .. _M.COLORS.RESET)
            return
        end
        ngx.log(ngx.DEBUG, "[LIFECYCLE] before_all completed successfully")
    end
    
    for _, test in ipairs(tests) do
        total = total + 1
        ngx.log(ngx.DEBUG, "\n[TEST] Starting test #" .. total .. ": " .. test.name)
        ngx.say("\nTest: " .. test.name)
        
        -- Run before_each if available
        if before_each then
            ngx.log(ngx.DEBUG, "[LIFECYCLE] Executing before_each for test: " .. test.name)
            local ok, err = pcall(before_each)
            if not ok then
                ngx.log(ngx.ERR, "[LIFECYCLE] before_each failed: " .. tostring(err))
                ngx.say(_M.COLORS.RED .. "Error in before_each: " .. err .. _M.COLORS.RESET)
                failed = failed + 1
                goto continue
            end
            ngx.log(ngx.DEBUG, "[LIFECYCLE] before_each completed successfully")
        end
        
        -- Execute test
        ngx.log(ngx.DEBUG, "[TEST] Executing test function")
        local ok, err = pcall(test.func)
        if ok then
            passed = passed + 1
            ngx.log(ngx.DEBUG, "[TEST] Test passed successfully")
        else
            failed = failed + 1
            ngx.log(ngx.ERR, "[TEST] Test failed with error: " .. tostring(err))
            ngx.say(_M.COLORS.RED .. "Error: " .. err .. _M.COLORS.RESET)
        end
        
        -- Run after_each if available
        if after_each then
            ngx.log(ngx.DEBUG, "[LIFECYCLE] Executing after_each for test: " .. test.name)
            local ok, err = pcall(after_each)
            if not ok then
                ngx.log(ngx.ERR, "[LIFECYCLE] after_each failed: " .. tostring(err))
                ngx.say(_M.COLORS.RED .. "Error in after_each: " .. err .. _M.COLORS.RESET)
            end
            ngx.log(ngx.DEBUG, "[LIFECYCLE] after_each completed")
        end
        
        ngx.log(ngx.DEBUG, "[TEST] Completed test: " .. test.name)
        ngx.log(ngx.DEBUG, "[STATE] ngx.status=" .. tostring(mock_status) .. 
                          ", ctx=" .. cjson.encode(ngx.ctx) .. 
                          ", headers=" .. cjson.encode(ngx.header))
        
        ::continue::
    end
    
    -- Run after_all if available
    if after_all then
        ngx.log(ngx.DEBUG, "[LIFECYCLE] Executing after_all")
        local ok, err = pcall(after_all)
        if not ok then
            ngx.log(ngx.ERR, "[LIFECYCLE] after_all failed: " .. tostring(err))
            ngx.say(_M.COLORS.RED .. "Error in after_all: " .. err .. _M.COLORS.RESET)
        end
        ngx.log(ngx.DEBUG, "[LIFECYCLE] after_all completed")
    end
    
    -- Teardown mocks after all tests complete
    _M.teardown_mocks()
    
    -- Log final test results
    ngx.log(ngx.INFO, string.format(
        "[SUMMARY] Test suite completed: %s\n" ..
        "Total tests: %d\n" ..
        "Passed: %d\n" ..
        "Failed: %d",
        test_path, total, passed, failed
    ))
    
    -- Print summary to output
    ngx.say("\nTest Summary:")
    ngx.say("Total: " .. total)
    ngx.say(_M.COLORS.GREEN .. "Passed: " .. passed .. _M.COLORS.RESET)
    if failed > 0 then
        ngx.say(_M.COLORS.RED .. "Failed: " .. failed .. _M.COLORS.RESET)
    else
        ngx.say("Failed: " .. failed)
    end
end

return _M 