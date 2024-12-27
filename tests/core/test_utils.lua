-- Test utilities module
local _M = {}

-- Helper function to print test results
function _M.assert_equals(expected, actual, message)
    if expected == actual then
        ngx.say("\27[32m✓\27[0m " .. message)
        return true
    else
        ngx.say("\27[31m✗\27[0m " .. message)
        ngx.say("  Expected: " .. tostring(expected))
        ngx.say("  Got: " .. tostring(actual))
        return false
    end
end

function _M.assert_not_nil(value, message)
    if value ~= nil then
        ngx.say("\27[32m✓\27[0m " .. message)
        return true
    else
        ngx.say("\27[31m✗\27[0m " .. message)
        return false
    end
end

-- Helper to run a test suite
function _M.run_suite(name, tests)
    ngx.say("\nRunning " .. name .. " tests...")
    local results = {
        passed = 0,
        failed = 0,
        total = #tests
    }

    for _, test in ipairs(tests) do
        ngx.say("\n" .. test.name)
        local ok, err = pcall(test.func)
        if ok then
            results.passed = results.passed + 1
        else
            results.failed = results.failed + 1
            ngx.say("Error: " .. tostring(err))
        end
    end

    ngx.say(string.format("\nResults: %d passed, %d failed", results.passed, results.failed))
    return results.failed == 0
end

return _M 