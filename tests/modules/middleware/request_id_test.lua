--- Test suite for request ID middleware
-- @module tests.modules.middleware.request_id_test

-- 1. Requires
local test_utils = require "tests.core.test_utils"
local request_id = require "modules.middleware.request_id"

-- 2. Local helper functions
local function setup_test_environment()
    test_utils.reset_state()
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
function _M.before_each()
    setup_test_environment()
end

-- 5. Test cases
_M.tests = {
    {
        name = "Test: New request ID generation",
        func = function()
            local results = run_middleware_phases()
            
            test_utils.assert_true(results.access_result, "Access phase should succeed")
            test_utils.assert_not_nil(results.stored_id, "Request ID should be generated")
            test_utils.assert_type(results.stored_id, "string", "Generated ID should be a string")
            test_utils.assert_equals(results.stored_id, results.response_id, 
                "Response header should match stored ID")
            test_utils.assert_true(results.header_result, "Header filter phase should succeed")
        end
    },
    {
        name = "Test: Incoming request ID preservation",
        func = function()
            local incoming_id = request_id._M.generate_request_id()
            local results = run_middleware_phases(incoming_id)
            
            test_utils.assert_true(results.access_result, "Access phase should succeed")
            test_utils.assert_equals(incoming_id, results.stored_id, 
                "Incoming request ID should be stored")
            test_utils.assert_equals(incoming_id, results.response_id, 
                "Response header should match incoming ID")
            test_utils.assert_true(results.header_result, "Header filter phase should succeed")
        end
    },
    {
        name = "Test: Malicious request ID validation",
        func = function()
            -- Table of malicious request IDs to test
            local malicious_ids = {
                -- SQL Injection attempts
                "1234'; DROP TABLE users; --",
                "668396f3-c758'; SELECT * FROM users; --",
                -- XSS attempts
                "<script>alert('xss')</script>",
                "668396f3-<img src=x onerror=alert(1)>",
                -- Path traversal attempts
                "../../../etc/passwd",
                "668396f3-c758-4d57-../../../",
                -- Command injection attempts
                "$(rm -rf /)",
                "`rm -rf /`",
                -- Oversized/wrong format
                "668396f3-c758-4d57-b014-63d3dc0dfa4c-extra",
                "668396f3c7584d57b01463d3dc0dfa4c",
                -- Non-hex characters
                "gggggggg-gggg-gggg-gggg-gggggggggggg",
                "zzzzzzzz-c758-4d57-b014-63d3dc0dfa4c",
                -- Empty/nil values
                "",
                "\n\n\n",
                -- Special characters
                "668396f3-c758-4d57-b014-####??????",
                "668396f3-c758-🦄🦄-b014-63d3dc0dfa4c"
            }

            for _, invalid_id in ipairs(malicious_ids) do
                local results = run_middleware_phases(invalid_id)
                
                test_utils.assert_true(results.access_result, 
                    "Access phase should succeed even with malicious ID: " .. invalid_id)
                test_utils.assert_not_equals(invalid_id, results.stored_id, 
                    "Malicious request ID should not be stored: " .. invalid_id)
                test_utils.assert_true(request_id._M.is_valid_uuid(results.stored_id), 
                    "Generated ID should be a valid UUID format")
            end

            -- Verify a valid UUID is accepted
            local valid_uuid = "668396f3-c758-4d57-b014-63d3dc0dfa4c"
            local results = run_middleware_phases(valid_uuid)
            test_utils.assert_true(results.access_result, 
                "Access phase should succeed for valid UUID")
            test_utils.assert_equals(valid_uuid, results.stored_id, 
                "Valid UUID should be stored unchanged")
        end
    }
}

return _M 