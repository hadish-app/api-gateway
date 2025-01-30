local cjson = require "cjson"

local _M = {}

-- Store original functions
local original_ngx_status
local original_ngx_exit
local original_ngx_ctx
local original_ngx_shared
local original_req_get_headers
local original_req_get_method
local original_req_get_uri_args
local original_req_get_post_args
local original_req_read_body
local original_req_get_body_data
local mock_status = 200

-- Mock state tracking
local mock_headers = {}
local mock_method = "GET"
local mock_uri = "/"
local mock_uri_args = {}
local mock_post_args = {}
local mock_body = ""
local response_headers = {}

-- Add to the original functions storage
local original_ngx_header

-- Create case-insensitive header handler
local header_handler = {
    __index = function(t, k)
        -- Convert header name to lowercase for lookup
        k = tostring(k):lower()
        return response_headers[k]
    end,
    __newindex = function(t, k, v)
        -- Store header with lowercase key
        k = tostring(k):lower()
        response_headers[k] = v
    end,
    __pairs = function()
        return next, response_headers
    end
}

-- Create header mock table
local header_mock = {}
setmetatable(header_mock, header_handler)

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
    BLUE = "\27[34m",
    RESET = "\27[0m"
}

-- Setup and teardown ngx mocks
function _M.setup_mocks()
    ngx.log(ngx.DEBUG, "[MOCK] Setting up ngx mocks")
    
    -- Store original values
    original_ngx_ctx = ngx.ctx
    original_ngx_shared = ngx.shared
    original_ngx_header = ngx.header  -- Store original header
    
    -- Initialize new context and header mock
    ngx.ctx = {}
    response_headers = {}  -- Reset response headers
    ngx.header = header_mock
    
    -- Store original ctx and shared
    ngx.log(ngx.DEBUG, "[MOCK] Storing original ngx.ctx and ngx.shared")
    original_ngx_ctx = ngx.ctx
    original_ngx_shared = ngx.shared
    ngx.ctx = {}
    
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
    original_req_get_headers = ngx.req.get_headers
    original_req_get_method = ngx.req.get_method
    original_req_get_uri_args = ngx.req.get_uri_args
    original_req_get_post_args = ngx.req.get_post_args
    original_req_read_body = ngx.req.read_body
    original_req_get_body_data = ngx.req.get_body_data
    
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
    
    -- Restore header mock
    if original_ngx_header then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.header")
        ngx.header = original_ngx_header
    end
    
    -- Restore status mock
    if original_ngx_status then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.status")
        setmetatable(ngx, original_ngx_status)
    end
    
    -- Restore exit mock
    if original_ngx_exit then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.exit")
        ngx.exit = original_ngx_exit
    end
    
    -- Restore ctx and shared
    if original_ngx_ctx then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.ctx")
        ngx.ctx = original_ngx_ctx
    end
    
    if original_ngx_shared then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.shared")
        ngx.shared = original_ngx_shared
    end
    
    -- Restore request functions
    if original_req_get_headers then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.get_headers")
        ngx.req.get_headers = original_req_get_headers
    end
    
    if original_req_get_method then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.get_method")
        ngx.req.get_method = original_req_get_method
    end
    
    if original_req_get_uri_args then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.get_uri_args")
        ngx.req.get_uri_args = original_req_get_uri_args
    end
    
    if original_req_get_post_args then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.get_post_args")
        ngx.req.get_post_args = original_req_get_post_args
    end
    
    if original_req_read_body then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.read_body")
        ngx.req.read_body = original_req_read_body
    end
    
    if original_req_get_body_data then
        ngx.log(ngx.DEBUG, "[MOCK] Restoring original ngx.req.get_body_data")
        ngx.req.get_body_data = original_req_get_body_data
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
        ", response_headers=" .. cjson.encode(response_headers))
    
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
    response_headers = {}
    ngx.header = header_mock
    
    -- Reset response headers separately from the mock
    response_headers = {}
    
    ngx.log(ngx.DEBUG, "[STATE] State reset completed: " .. cjson.encode(ngx.header))
end

-- Core assertions
function _M.assert_equals(expected, actual, message)
    if expected == actual then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected: " .. tostring(expected))
        ngx.say("  Got: " .. tostring(actual))
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
        return false
    end
end

function _M.assert_not_equals(expected, actual, message)
    if expected ~= actual then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected not to equal: " .. tostring(expected))
        ngx.say("  Got: " .. tostring(actual))
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
        return false
    end
end

function _M.assert_not_nil(value, message)
    if value ~= nil then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected value to not be nil")
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
        return false
    end
end

function _M.assert_nil(value, message)
    if value == nil then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected nil but got: " .. tostring(value))
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
        return false
    end
end

function _M.assert_true(value, message)
    if value == true then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected true but got: " .. tostring(value))
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
        return false
    end
end

function _M.assert_false(value, message)
    if value == false then
        ngx.say(_M.COLORS.GREEN .. "✓" .. _M.COLORS.RESET .. " " .. message)
        ngx.ctx.test_successes = (ngx.ctx.test_successes or 0) + 1
        return true
    else
        ngx.say(_M.COLORS.RED .. "✗" .. _M.COLORS.RESET .. " " .. message)
        ngx.say("  Expected false but got: " .. tostring(value))
        ngx.ctx.test_failures = (ngx.ctx.test_failures or 0) + 1
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

function _M.find_test_files(path, results)
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Finding test files for path: " .. path)
    results = results or {}
    
    -- Get OpenResty's prefix path and ensure clean path concatenation
    local prefix = ngx.config.prefix():gsub("/$", "")  -- Remove trailing slash if present
    local clean_path = path:gsub("^/", "")  -- Remove leading slash if present
    local full_path = prefix .. "/" .. clean_path
    
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Looking for tests in: " .. full_path)
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Original path: " .. path)
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Prefix path: " .. prefix)
    
    -- Check if path exists
    local handle = io.popen('[ -e "' .. full_path .. '" ] && echo "exists"')
    local exists = handle:read("*a")
    handle:close()
    
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Path exists check result: " .. tostring(exists ~= ""))
    
    if exists == "" then
        -- If path doesn't exist, try appending _test.lua
        if not string.match(path, "_test%.lua$") then
            local test_path = path .. "_test.lua"
            ngx.log(ngx.DEBUG, "[TEST_RUNNER] Path doesn't exist, trying with _test.lua: " .. test_path)
            return _M.find_test_files(test_path, results)
        end
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Path doesn't exist and already ends with _test.lua")
        return nil, "Path does not exist: " .. path
    end
    
    -- Check if it's a directory
    handle = io.popen('[ -d "' .. full_path .. '" ] && echo "dir"')
    local is_dir = handle:read("*a")
    handle:close()
    
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Is directory check result: " .. tostring(is_dir ~= ""))
    
    if is_dir ~= "" then
        -- It's a directory, list all files
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Path is a directory, searching for test files")
        handle = io.popen('find "' .. full_path .. '" -type f -name "*_test.lua"')
        local files = handle:read("*a")
        handle:close()
        
        -- Split files by newline and add to results
        for file in string.gmatch(files, "[^\n]+") do
            -- Convert absolute path back to relative path
            local relative_path = string.sub(file, #prefix + 2)
            ngx.log(ngx.DEBUG, "[TEST_RUNNER] Found test file: " .. relative_path)
            table.insert(results, relative_path)
        end
        
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Total test files found in directory: " .. #results)
    else
        -- It's a file, check if it's a test file
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Path is a file")
        if string.match(path, "_test%.lua$") then
            ngx.log(ngx.DEBUG, "[TEST_RUNNER] File is a test file, returning single file: " .. path)
            -- For single test files, we should only return this file
            return {path}
        else
            ngx.log(ngx.DEBUG, "[TEST_RUNNER] File is not a test file: " .. path)
        end
    end
    
    -- Only return results if we found any test files
    if #results > 0 then
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Returning " .. #results .. " test files")
        return results
    else
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] No test files found")
        return nil, "No test files found in path: " .. path
    end
end

function _M.run_tests(path)
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Starting test execution for path: " .. path)
    
    -- Find all test files
    local test_files, err = _M.find_test_files(path)
    if not test_files then
        ngx.log(ngx.ERR, "[TEST_RUNNER] Error finding test files: " .. err)
        return false, err
    end
    
    ngx.log(ngx.DEBUG, "[TEST_RUNNER] Found " .. #test_files .. " test files to execute")
    for i, file in ipairs(test_files) do
        ngx.log(ngx.DEBUG, "[TEST_RUNNER] Test file " .. i .. ": " .. file)
    end
    
    if #test_files == 0 then
        ngx.log(ngx.WARN, "[TEST_RUNNER] No test files found in path: " .. path)
        ngx.say("No test files found in path: " .. path)
        return true
    end
    
    -- Sort test files for consistent execution order
    table.sort(test_files)
    
    -- Track overall statistics
    local total_tests = 0
    local total_passed = 0
    local total_failed = 0
    local total_assertions = 0
    local total_assertions_passed = 0
    local total_assertions_failed = 0
    local failed_tests = {}
    
    -- Run each test file
    for _, test_file in ipairs(test_files) do
        ngx.log(ngx.INFO, "[TEST_RUNNER] Running test file: " .. test_file)
        ngx.say(_M.COLORS.YELLOW .. "\n=== Running tests from: " .. test_file .. " ===\n" .. _M.COLORS.RESET)
        
        -- Load the test module
        local ok, test_module = pcall(require, string.gsub(test_file:sub(1, -5), "/", "."))
        if not ok then
            ngx.log(ngx.ERR, "[TEST_RUNNER] Error loading test module: " .. test_module)
            ngx.say(_M.COLORS.RED .. "Error loading test module: " .. test_module .. _M.COLORS.RESET)
            table.insert(failed_tests, {
                file = test_file,
                error = "Failed to load module: " .. test_module
            })
            goto continue
        end
        
        -- Run the test suite
        local before_suite = test_module.before_all
        local after_suite = test_module.after_all
        local before_each = test_module.before_each
        local after_each = test_module.after_each
        
        -- Setup test environment
        _M.setup_mocks()
        
        -- Run before_all if available
        if before_suite then
            local ok, err = pcall(before_suite)
            if not ok then
                ngx.log(ngx.ERR, "[TEST_RUNNER] before_all failed: " .. tostring(err))
                ngx.say(_M.COLORS.RED .. "Error in before_all: " .. err .. _M.COLORS.RESET)
                goto continue
            end
        end
        
        -- Run individual tests
        local suite_total = 0
        local suite_passed = 0
        local suite_failed = 0
        local assertion_total = 0
        local assertion_passed = 0
        local assertion_failed = 0
        
        for _, test in ipairs(test_module.tests or {}) do
            suite_total = suite_total + 1
            ngx.log(ngx.DEBUG, "[TEST_RUNNER] Running test: " .. test.name)
            ngx.say("\nTest: " .. test.name)
            
            -- Reset test counters
            ngx.ctx.test_failures = 0
            ngx.ctx.test_successes = 0
            
            -- Run before_each
            if before_each then
                local ok, err = pcall(before_each)
                if not ok then
                    ngx.log(ngx.ERR, "[TEST_RUNNER] before_each failed: " .. tostring(err))
                    ngx.say(_M.COLORS.RED .. "Error in before_each: " .. err .. _M.COLORS.RESET)
                    suite_failed = suite_failed + 1
                    goto next_test
                end
            end
            
            -- Run test
            local ok, err = pcall(test.func)
            
            -- Update assertion statistics
            assertion_total = assertion_total + (ngx.ctx.test_successes or 0) + (ngx.ctx.test_failures or 0)
            assertion_failed = assertion_failed + (ngx.ctx.test_failures or 0)
            assertion_passed = assertion_passed + (ngx.ctx.test_successes or 0)
            
            if ok and ngx.ctx.test_failures == 0 then
                suite_passed = suite_passed + 1
            else
                suite_failed = suite_failed + 1
                if not ok then
                    ngx.log(ngx.ERR, "[TEST_RUNNER] Test failed: " .. tostring(err))
                    ngx.say(_M.COLORS.RED .. "Error: " .. err .. _M.COLORS.RESET)
                end
            end
            
            -- Run after_each
            if after_each then
                local ok, err = pcall(after_each)
                if not ok then
                    ngx.log(ngx.ERR, "[TEST_RUNNER] after_each failed: " .. tostring(err))
                    ngx.say(_M.COLORS.RED .. "Error in after_each: " .. err .. _M.COLORS.RESET)
                end
            end
            
            ::next_test::
        end
        
        -- Run after_all if available
        if after_suite then
            local ok, err = pcall(after_suite)
            if not ok then
                ngx.log(ngx.ERR, "[TEST_RUNNER] after_all failed: " .. tostring(err))
                ngx.say(_M.COLORS.RED .. "Error in after_all: " .. err .. _M.COLORS.RESET)
            end
        end
        
        -- Teardown test environment
        _M.teardown_mocks()
        
        -- Update overall statistics
        total_tests = total_tests + suite_total
        total_passed = total_passed + suite_passed
        total_failed = total_failed + suite_failed
        total_assertions = (total_assertions or 0) + assertion_total
        total_assertions_passed = (total_assertions_passed or 0) + assertion_passed
        total_assertions_failed = (total_assertions_failed or 0) + assertion_failed
        
        -- Print suite summary
        ngx.say("\nSuite Summary for " .. test_file .. ":")
        ngx.say("\nTests:")
        ngx.say("Total: " .. suite_total)
        ngx.say(_M.COLORS.GREEN .. "Passed: " .. suite_passed .. _M.COLORS.RESET)
        if suite_failed > 0 then
            ngx.say(_M.COLORS.RED .. "Failed: " .. suite_failed .. _M.COLORS.RESET)
        else
            ngx.say("Failed: " .. suite_failed)
        end
        
        ngx.say("\nAssertions:")
        ngx.say("Total: " .. assertion_total)
        ngx.say(_M.COLORS.GREEN .. "Passed: " .. assertion_passed .. _M.COLORS.RESET)
        if assertion_failed > 0 then
            ngx.say(_M.COLORS.RED .. "Failed: " .. assertion_failed .. _M.COLORS.RESET)
        else
            ngx.say("Failed: " .. assertion_failed)
        end
        
        ::continue::
    end
    
    -- Print overall summary
    ngx.say(_M.COLORS.BLUE .. "\n=== Overall Test Summary ===\n" .. _M.COLORS.RESET)
    ngx.say("Total Test Files: " .. #test_files)
    
    ngx.say("\nTests:")
    ngx.say("Total: " .. total_tests)
    ngx.say(_M.COLORS.GREEN .. "Passed: " .. total_passed .. _M.COLORS.RESET)
    if total_failed > 0 then
        ngx.say(_M.COLORS.RED .. "Failed: " .. total_failed .. _M.COLORS.RESET)
    else
        ngx.say("Failed: " .. total_failed)
    end
    
    ngx.say("\nAssertions:")
    ngx.say("Total: " .. total_assertions)
    ngx.say(_M.COLORS.GREEN .. "Passed: " .. total_assertions_passed .. _M.COLORS.RESET)
    if total_assertions_failed > 0 then
        ngx.say(_M.COLORS.RED .. "Failed: " .. total_assertions_failed .. _M.COLORS.RESET)
    else
        ngx.say("Failed: " .. total_assertions_failed)
    end
    
    -- Print failed tests if any
    if #failed_tests > 0 then
        ngx.say("\n" .. _M.COLORS.RED .. "Failed Test Files:" .. _M.COLORS.RESET)
        for _, failure in ipairs(failed_tests) do
            ngx.say(failure.file .. ": " .. failure.error)
        end
    end
    
    return true
end

return _M 