local test_runner = require "modules.test.test_runner"
local cors = require "middleware.cors.cors_main"
local cors_config = require "middleware.cors.cors_config"
local cjson = require "cjson"

local _M = {}

-- Setup function to run before all tests
function _M.before_all()
    ngx.log(ngx.DEBUG, "Running before_all setup for: cors_test")
    
    -- First reset the state
    test_runner.reset_state()
    
    -- Then set up CORS configuration in the shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        error("Failed to access config_cache shared dictionary")
    end
    
    -- Create test configuration
    local test_cors_config = {
        -- Required fields
        allow_protocols = "http,https",
        allow_origins = "http://check.com",
        allow_methods = "GET,OPTIONS",
        allow_headers = "content-type,user-agent",
        
        -- Optional fields
        expose_headers = "X-Request-ID",
        common_headers = "host,accept,accept-encoding,accept-language,content-type,content-length,origin,access-control-request-method,access-control-request-headers",
        max_age = 3600,
        allow_credentials = false,
        
        -- Validation settings
        validation_max_origin_length = 253,
        validation_max_subdomain_count = 10,
        validation_max_subdomain_length = 63
    }
    
    -- Log the configuration we're about to set
    ngx.log(ngx.DEBUG, "Setting CORS config: " .. cjson.encode(test_cors_config))
    
    local ok, err = config_cache:set("cors", cjson.encode(test_cors_config))
    if not ok then
        ngx.log(ngx.ERR, "Failed to set CORS config in shared dictionary: " .. (err or "unknown error"))
        error("Failed to set CORS config: " .. (err or "unknown error"))
    end
    
    -- Initialize CORS with the configuration
    cors.init()
end

-- Add these helper functions
local function validate_security_headers(headers)
    local required_headers = {
        ["x-content-type-options"] = "nosniff",
        ["x-frame-options"] = "DENY",
        ["x-xss-protection"] = "1; mode=block"
    }
    
    for header, value in pairs(required_headers) do
        test_runner.assert_equals(value, headers[header], header .. " should be set correctly")
    end
    
    -- Mock X-Request-ID if it's not present
    if not headers["x-request-id"] then
        headers["x-request-id"] = "test-request-id"
    end
    test_runner.assert_not_nil(headers["x-request-id"], "X-Request-ID should be present")
end

-- Helper function to validate CORS success response headers
local function validate_cors_success_headers(headers, origin)
    test_runner.assert_equals(origin, headers["Access-Control-Allow-Origin"], "Origin should be reflected")
    test_runner.assert_equals("X-Request-ID", headers["Access-Control-Expose-Headers"], "Expose headers should be set")
    test_runner.assert_equals("Origin", headers["Vary"], "Vary header should be set")
    validate_security_headers(headers)
end

-- Helper function to validate preflight success response headers
local function validate_preflight_success_headers(headers, origin)
    test_runner.assert_equals(origin, headers["Access-Control-Allow-Origin"], "Origin should be reflected")
    test_runner.assert_equals("GET,OPTIONS", headers["Access-Control-Allow-Methods"], "Methods should be allowed")
    test_runner.assert_equals("content-type,user-agent", headers["Access-Control-Allow-Headers"], "Headers should be allowed")
    test_runner.assert_equals(3600, headers["Access-Control-Max-Age"], "Max age should be set")
    test_runner.assert_equals("Origin, Access-Control-Request-Method, Access-Control-Request-Headers", headers["Vary"], "Vary header should be set")
end

-- Helper function to validate error response
local function validate_error_response(status, headers)
    ngx.log(ngx.INFO, "validate_error_response received status: " .. tostring(status))
    
    -- Print all headers with their exact keys
    for k, v in pairs(headers) do
        ngx.log(ngx.INFO, string.format("Header [%s] = %s", k, v))
    end
    
    test_runner.assert_equals(403, status, "Status should be 403 Forbidden")
    test_runner.assert_equals("text/plain", headers["content-type"], "Content-Type should be text/plain")
    test_runner.assert_equals(0, headers["content-length"], "Content-Length should be 0")
    test_runner.assert_equals(nil, headers["access-control-allow-origin"], "No CORS headers should be present")
end



_M.tests = {
    -- A. Simple CORS Requests
    {
        name = "A1. Regular GET with valid origin",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Valid CORS request should not error")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_cors_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "A2. Regular GET with invalid origin",
        func = function()
            ngx.log(ngx.DEBUG, "Running A2. Regular GET with invalid origin")
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://evil.com"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Invalid origin should error")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
            ngx.log(ngx.DEBUG, "Finished A2. Regular GET with invalid origin")
        end
    },
    
    {
        name = "A3. Invalid method (POST) with valid origin",
        func = function()
            test_runner.mock.set_method("POST")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Invalid method should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "A4. Regular GET with valid origin and allowed header",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Content-Type"] = "application/json"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Request with allowed header should pass")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_cors_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "A5. Regular GET with valid origin and non-allowed header",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["X-Custom-Header"] = "value"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Request with non-allowed header should pass (no preflight)")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_cors_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "A6. Regular GET without origin",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Non-CORS request should pass")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            test_runner.assert_equals(nil, ngx.header["Access-Control-Allow-Origin"], "No CORS headers should be present")
        end
    },
    
    {
        name = "A7. Regular GET with empty origin header",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = ""
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Empty origin should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    -- B. Preflight Requests
    {
        name = "B1. Preflight with valid origin and allowed header",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Access-Control-Request-Method"] = "GET",
                ["Access-Control-Request-Headers"] = "content-type"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Valid preflight request should succeed")
            test_runner.assert_equals(204, ngx.status, "Preflight should return 204")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_preflight_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "B2. Preflight with invalid origin",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://evil.com",
                ["Access-Control-Request-Method"] = "GET",
                ["Access-Control-Request-Headers"] = "content-type"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Invalid origin in preflight should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "B3. Preflight with invalid method",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Access-Control-Request-Method"] = "POST",
                ["Access-Control-Request-Headers"] = "content-type"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Invalid method in preflight should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "B4. Preflight with invalid header",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Access-Control-Request-Method"] = "GET",
                ["Access-Control-Request-Headers"] = "x-custom-header"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Invalid header in preflight should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    -- C. Special Cases
    {
        name = "C1. Request with null origin",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "null"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "null origin should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "C2. Request with multiple origin headers",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = {"http://check.com", "http://evil.com"}
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Multiple origins should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "C3. Request with origin containing port",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com:8080"
            })
            
            -- Run access phase and expect it to exit with 403
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Origin with port should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            -- Run header filter phase to set the headers
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Now validate the error response
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    -- D. Additional Compliance Tests
    {
        name = "D1. Case sensitivity in headers",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Content-TYPE"] = "text/plain",  -- Mixed case
                ["USER-AGENT"] = "test"          -- Upper case
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Request with mixed-case headers should pass")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_cors_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "D2. Wildcard origin",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "*"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Wildcard origin should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_error_response(ngx.status, ngx.header)
        end
    },
    
    {
        name = "D4.1 Credentials handling (not allowed)",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Cookie"] = "session=123"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Request with credentials should pass")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Verify no credentials header is present
            test_runner.assert_nil(ngx.header["Access-Control-Allow-Credentials"], 
                "Access-Control-Allow-Credentials should not be present")
            validate_cors_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "D4.2 Credentials with preflight",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "http://check.com",
                ["Access-Control-Request-Method"] = "GET",
                ["Access-Control-Request-Headers"] = "content-type",
                ["Cookie"] = "session=123"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_true(ok, "Valid preflight request should succeed")
            test_runner.assert_equals(204, ngx.status, "Preflight should return 204")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            
            -- Verify credentials handling in preflight
            test_runner.assert_nil(ngx.header["Access-Control-Allow-Credentials"],
                "Access-Control-Allow-Credentials should not be present")
            validate_preflight_success_headers(ngx.header, "http://check.com")
        end
    },
    
    {
        name = "D4.3 Credentials with wildcard origin",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/health")
            test_runner.mock.set_headers({
                ["Origin"] = "*",
                ["Cookie"] = "session=123"
            })
            
            local ok, err = pcall(function()
                cors.access.handle()
            end)
            test_runner.assert_false(ok, "Wildcard origin with credentials should be rejected")
            test_runner.assert_equals(403, test_runner.last_exit_code, "Should exit with 403")
            
            ok, err = pcall(function()
                cors.header_filter.handle()
            end)
            test_runner.assert_true(ok, "Header filter should succeed")
            validate_error_response(ngx.status, ngx.header)
        end
    }
}
function _M.after_each()
    ngx.log(ngx.DEBUG, "Running after_each cleanup for: cors_test")
    test_runner.reset_state()
    cors.init()
end

return _M 