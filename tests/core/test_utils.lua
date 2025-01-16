--- Test utilities module
-- @module tests.core.test_utils
-- @description Common utilities and assertions for tests

local cjson = require "cjson"

local _M = {}

-- Constants
_M.COLORS = {
    RED = "\27[31m",
    GREEN = "\27[32m",
    YELLOW = "\27[33m",
    RESET = "\27[0m"
}

-- State management
function _M.reset_state()
    ngx.ctx = {}
    ngx.header = {}
    -- Reset shared dictionaries if they exist
    if ngx.shared then
        for dict_name, dict in pairs(ngx.shared) do
            dict:flush_all()
        end
    end
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
function _M.run_suite(test_path, tests)
    ngx.say(_M.COLORS.YELLOW .. "\nRunning test suite: " .. test_path .. _M.COLORS.RESET)
    
    local total = 0
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        total = total + 1
        ngx.say("\nTest: " .. test.name)
        
        local ok, err = pcall(test.func)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            ngx.say(_M.COLORS.RED .. "Error: " .. err .. _M.COLORS.RESET)
        end
    end
    
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