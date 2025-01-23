--- Test suite for request ID middleware
-- @module tests.modules.middleware.request_id_test

-- 1. Requires
local test_runner = require "modules.test.test_runner"
local request_id = require "middleware.request_id"
local cjson = require "cjson"

-- 2. Local helper functions
local function setup_test_environment()
    test_runner.reset_state()
    -- Reset request headers
    ngx.req.get_headers = function()
        return {}
    end
end

local function mock_request_headers(headers)
    ngx.req.get_headers = function()
        return headers or {}
    end
end

local function mock_response_headers()
    local original_header = ngx.header
    ngx.header = setmetatable({}, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
        end
    })
    return original_header
end

local function run_middleware_phases(incoming_id)
    if incoming_id then
        mock_request_headers({ ["X-Request-ID"] = incoming_id })
    end

    -- Run access phase
    local access_result = request_id.access:handle()
    local stored_id = request_id._M.get_request_id()

    -- Run header filter phase with mocked headers
    local original_header = mock_response_headers()
    local header_result = request_id.header_filter:handle()
    local response_id = ngx.header["X-Request-ID"]
    ngx.header = original_header

    return {
        access_result = access_result,
        header_result = header_result,
        stored_id = stored_id,
        response_id = response_id
    }
end

-- 3. Module definition
local _M = {}

-- 4. Test setup
function _M.before_all()
    ngx.log(ngx.DEBUG, "Running before_all setup for: request_id_test")
    test_runner.reset_state()
end

function _M.before_each()
    ngx.log(ngx.DEBUG, "Running before_each setup for: request_id_test")
    test_runner.reset_state()
    
    -- Log initial state for debugging
    ngx.log(ngx.DEBUG, "Initial test state:")
    ngx.log(ngx.DEBUG, "ngx.status: " .. ngx.status)
    ngx.log(ngx.DEBUG, "ngx.ctx: " .. cjson.encode(ngx.ctx))
    ngx.log(ngx.DEBUG, "ngx.header: " .. cjson.encode(ngx.header))
end

-- 5. Test cases
_M.tests = {
    {
        name = "Test: New request ID generation",
        func = function()
            -- Setup request without X-Request-ID
            test_runner.mock.set_headers({})
            test_runner.mock.set_method("GET")
            
            -- Run access phase
            local access_result = request_id.access:handle()
            test_runner.assert_true(access_result, "Access phase should succeed")
            
            -- Verify request ID was generated and stored
            local stored_id = request_id._M.get_request_id()
            test_runner.assert_not_nil(stored_id, "Request ID should be generated")
            test_runner.assert_type(stored_id, "string", "Generated ID should be a string")
            test_runner.assert_true(request_id._M.is_valid_uuid(stored_id), 
                "Generated ID should be a valid UUID")
            
            -- Run header filter phase
            local header_result = request_id.header_filter:handle()
            test_runner.assert_true(header_result, "Header filter phase should succeed")
            
            -- Verify response header
            test_runner.assert_equals(stored_id, ngx.header["X-Request-ID"], 
                "Response header should match stored ID")
        end
    },
    {
        name = "Test: Incoming request ID preservation",
        func = function()
            -- Generate and set incoming request ID
            local incoming_id = request_id._M.generate_request_id()
            test_runner.mock.set_headers({
                ["X-Request-ID"] = incoming_id
            })
            test_runner.mock.set_method("GET")
            
            -- Run access phase
            local access_result = request_id.access:handle()
            test_runner.assert_true(access_result, "Access phase should succeed")
            
            -- Verify incoming ID was preserved
            local stored_id = request_id._M.get_request_id()
            test_runner.assert_equals(incoming_id, stored_id, 
                "Incoming request ID should be stored")
            
            -- Run header filter phase
            local header_result = request_id.header_filter:handle()
            test_runner.assert_true(header_result, "Header filter phase should succeed")
            
            -- Verify response header matches incoming ID
            test_runner.assert_equals(incoming_id, ngx.header["X-Request-ID"], 
                "Response header should match incoming ID")
        end
    },
    {
        name = "Test: Malicious request ID validation",
        func = function()
            -- Table of malicious request IDs to test
            local malicious_ids = {
                -- SQL Injection attempts
                "1234'; DROP TABLE users; --",
                -- XSS attempts
                "<script>alert('xss')</script>",
                -- Path traversal attempts
                "../../../etc/passwd",
                -- Command injection attempts
                "$(rm -rf /)",
                -- Oversized/wrong format
                "668396f3-c758-4d57-b014-63d3dc0dfa4c-extra",
                -- Non-hex characters
                "gggggggg-gggg-gggg-gggg-gggggggggggg",
                -- Empty/nil values
                "",
                -- Special characters
                "668396f3-🦄🦄-4d57-b014-63d3dc0dfa4c"
            }

            for _, invalid_id in ipairs(malicious_ids) do
                ngx.log(ngx.DEBUG, "Testing malicious ID: " .. invalid_id)
                
                test_runner.mock.set_headers({
                    ["X-Request-ID"] = invalid_id
                })
                test_runner.mock.set_method("GET")
                
                -- Run access phase
                local access_result = request_id.access:handle()
                test_runner.assert_true(access_result, 
                    "Access phase should succeed even with malicious ID: " .. invalid_id)
                
                -- Verify malicious ID was rejected
                local stored_id = request_id._M.get_request_id()
                test_runner.assert_not_equals(invalid_id, stored_id, 
                    "Malicious request ID should not be stored: " .. invalid_id)
                test_runner.assert_true(request_id._M.is_valid_uuid(stored_id), 
                    "Generated ID should be a valid UUID format")
            end

            -- Verify valid UUID is accepted
            local valid_uuid = "668396f3-c758-4d57-b014-63d3dc0dfa4c"
            test_runner.mock.set_headers({
                ["X-Request-ID"] = valid_uuid
            })
            
            local access_result = request_id.access:handle()
            test_runner.assert_true(access_result, "Access phase should succeed for valid UUID")
            
            local stored_id = request_id._M.get_request_id()
            test_runner.assert_equals(valid_uuid, stored_id, "Valid UUID should be stored unchanged")
        end
    }
}

-- Cleanup function to run after each test
function _M.after_each()
    ngx.log(ngx.DEBUG, "Running after_each cleanup for: request_id_test")
    test_runner.reset_state()
    
    -- Log final state for debugging
    ngx.log(ngx.DEBUG, "Final test state:")
    ngx.log(ngx.DEBUG, "ngx.status: " .. ngx.status)
    ngx.log(ngx.DEBUG, "ngx.ctx: " .. cjson.encode(ngx.ctx))
    ngx.log(ngx.DEBUG, "ngx.header: " .. cjson.encode(ngx.header))
end

-- Cleanup function to run after all tests
function _M.after_all()
    ngx.log(ngx.DEBUG, "Running after_all cleanup for: request_id_test")
    test_runner.reset_state()
end

return _M 