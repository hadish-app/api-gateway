local test_utils = require "tests.core.test_utils"
local cors = require "modules.middleware.cors.cors_init"
local cjson = require "cjson"


local _M = {}

-- Setup function to run before all tests
function _M.before_all()
    ngx.log(ngx.DEBUG, "Running before_all setup for: cors_test")
    test_utils.reset_state()

end

-- Setup function to run before each test
function _M.before_each()
    ngx.log(ngx.DEBUG, "Running before_each setup for: cors_test")
    test_utils.reset_state()

    ngx.log(ngx.DEBUG, "ngx.status: " .. ngx.status)
    ngx.log(ngx.DEBUG, "ngx.ctx: " .. cjson.encode(ngx.ctx))
    ngx.log(ngx.DEBUG, "ngx.header: " .. cjson.encode(ngx.header))

end

_M.tests = {
    -- Basic functionality test
    {
        name = "Non-CORS request should pass through",
        func = function()            
            test_utils.mock.set_headers({})
            test_utils.mock.set_method("GET")
            local result = cors.access:handle()
            test_utils.assert_true(result, "Access handler should return true")            
            test_utils.assert_not_nil(ngx.ctx.cors, "CORS context should be set")
            test_utils.assert_equals(ngx.ctx.cors.is_cors, false, "is_cors should be false")
            test_utils.assert_equals(ngx.ctx.cors.is_preflight, false, "is_preflight should be false")
            test_utils.assert_nil(ngx.ctx.cors.origin, "origin should be nil")
            test_utils.assert_nil(ngx.header["Access-Control-Allow-Origin"], "CORS headers should not be set")
        end
    },
    
    -- Valid CORS request test
    {
        name = "Valid CORS request should be processed correctly",
        func = function()            
            -- Setup request with Origin header
            test_utils.mock.set_headers({
                Origin = "https://example.com"
            })
            test_utils.mock.set_method("GET")

            -- Configure CORS with specific origin
            cors.configure({
                allow_origins = {"https://example.com"},
                allow_methods = {"GET"},
                allow_headers = {"Content-Type"}
            })
            
            -- Test access phase
            local access_result = cors.access:handle()
            test_utils.assert_true(access_result, "Access handler should return true")
            test_utils.assert_not_nil(ngx.ctx.cors, "CORS context should be set")
            test_utils.assert_equals(ngx.ctx.cors.is_cors, true, "is_cors should be true")
            test_utils.assert_equals(ngx.ctx.cors.is_preflight, false, "is_preflight should be false")
            test_utils.assert_equals(ngx.ctx.cors.origin, "https://example.com", "origin should match")
            
            -- Test header filter phase
            local header_result = cors.header_filter:handle()
            test_utils.assert_true(header_result, "Header filter should return true")
            test_utils.assert_equals(
                ngx.header["Access-Control-Allow-Origin"],
                "https://example.com",
                "Origin should be allowed in response headers"
            )
            test_utils.assert_not_nil(
                ngx.header["Vary"],
                "Vary header should be set"
            )
        end
    },
    
    -- Invalid CORS request tests
    {
        name = "CORS request with disallowed origin",
        func = function()            
            
            -- Setup request with disallowed origin
            test_utils.mock.set_headers({
                Origin = "https://evil.com"
            })
            test_utils.mock.set_method("GET")
            
            -- Configure middleware with specific allowed origins
            cors.configure({
                allow_origins = {"https://allowed.com"},
                allow_methods = {"GET"},
                allow_headers = {"Content-Type"}
            })
            
            -- Test access phase and expect ngx.exit to be called
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should exit with error")
            test_utils.assert_matches(err, "^ngx%.exit%(403%)$", "Should exit with forbidden status")            
        end
    },
    
    {
        name = "CORS request with invalid HTTP method",
        func = function()            
            
            -- Setup request with invalid method
            test_utils.mock.set_headers({
                Origin = "https://example.com"
            })
            test_utils.mock.set_method("INVALID")
            
            -- Configure middleware with specific allowed methods
            cors.configure({
                allow_origins = {"https://example.com"},
                allow_methods = {"GET", "POST"},
                allow_headers = {"Content-Type"}
            })
            
            -- Test access phase
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should exit with error")
            test_utils.assert_matches(err, "^ngx%.exit%(403%)$", "Should exit with forbidden status")
        end
    },
     
    {
        name = "CORS request with invalid headers",
        func = function()            
            
            -- Setup request with invalid header
            test_utils.mock.set_headers({
                Origin = "https://example.com",
                ["Invalid-Header"] = "value"
            })
            test_utils.mock.set_method("GET")
            
            
            -- Configure middleware with specific allowed headers
            cors.configure({
                allow_origins = {"https://example.com"},
                allow_methods = {"GET"},
                allow_headers = {"Content-Type"}
            })
            
            -- Test access phase
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should exit with error")
            test_utils.assert_matches(err, "^ngx%.exit%(403%)$", "Should exit with forbidden status")
        end
    },    
    
    {
        name = "CORS request with malformed origin",
        func = function()            
            
            -- Setup request with malformed origin
            test_utils.mock.set_headers({
                Origin = "not-a-valid-url"
            })
            test_utils.mock.set_method("GET")
            
            -- Test access phase
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should exit with error")
            test_utils.assert_matches(err, "^ngx%.exit%(403%)$", "Should exit with forbidden status")
        end
    },
    
    -- Config validation tests
    {
        name = "Config validation - invalid allow_origins",
        func = function()            
            
            -- Test with invalid string value
            local ok, err = pcall(function()
                cors.configure({
                    allow_origins = "not_an_array"
                })
            end)
            test_utils.assert_false(ok, "Should fail with string allow_origins")
            test_utils.assert_matches(err, "allow_origins must be a non%-empty array", "Should have correct error message")
            
            -- Test with empty array
            ok, err = pcall(function()
                cors.configure({
                    allow_origins = {}
                })
            end)
            test_utils.assert_false(ok, "Should fail with empty allow_origins")
            test_utils.assert_matches(err, "allow_origins must be a non%-empty array", "Should have correct error message")
            
            -- Test with valid array (should pass)
            ok, err = pcall(function()
                cors.configure({
                    allow_origins = {"https://example.com"},
                    allow_methods = {"GET"},
                    allow_headers = {"Content-Type"}
                })
            end)
            test_utils.assert_true(ok, "Should succeed with valid allow_origins")
        end
    },
   
    {
        name = "Config validation - credentials with wildcard origin",
        func = function()            
            local ok, err = pcall(function()
                cors.configure({
                    allow_origins = {"*"},
                    allow_credentials = true
                })
            end)
            test_utils.assert_false(ok, "Should fail with wildcard origin and credentials")
        end
    }, 
   
    -- Header sanitization tests
    {
        name = "Header sanitization - malicious origin",
        func = function()            
            
            test_utils.mock.set_headers({
                Origin = "https://good.com\r\nmalicious-header: bad"
            })
            test_utils.mock.set_method("GET")
            
            -- Test access phase
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should exit with error")
            test_utils.assert_matches(err, "^ngx%.exit%(403%)$", "Should exit with forbidden status")
        end
    },
    
    -- Vary header tests
    {
        name = "Vary header handling",
        func = function()            
            test_utils.mock.set_headers({
                Origin = "https://example.com"
            })
            test_utils.mock.set_method("GET")
            
            ngx.log(ngx.DEBUG, "Vary header before: " .. cjson.encode(ngx.header))
            cors.access:handle()
            cors.header_filter:handle()
            ngx.log(ngx.DEBUG, "Vary header after: " .. cjson.encode(ngx.header))

            local vary = ngx.header["Vary"]
            test_utils.assert_not_nil(vary, "Vary header should be set")
            test_utils.assert_true(
                string.find(vary, "Origin") ~= nil,
                "Vary header should contain Origin"
            )
        end
    },
    
    -- Common headers tests
    {
        name = "Common headers are always allowed",
        func = function()            
            test_utils.mock.set_headers({
                Origin = "https://example.com",
                Accept = "application/json",
                ["User-Agent"] = "test-agent",
                Host = "api.example.com"
            })
            test_utils.mock.set_method("GET")
            
            local result = cors.access:handle()
            test_utils.assert_true(result, "Should allow common headers")
        end
    },
    
    -- Multiple header validation test
    {
        name = "Multiple custom headers validation",
        func = function()            

            -- ngx.log(ngx.DEBUG, "Current config: " .. cjson.encode(cors.get_config()))

            local new_config = cors.configure({
                allow_origins = {"https://example.com"},
                allow_headers = {"Custom-Header-1", "Custom-Header-2"},
                allow_methods = {"GET"}
            })

            ngx.log(ngx.DEBUG, "New config: " .. cjson.encode(new_config))
            
            test_utils.mock.set_headers({
                Origin = "https://example.com",
                ["Custom-Header-1"] = "value1",
                ["Custom-Header-2"] = "value2"
            })
            test_utils.mock.set_method("GET")
            
            local result = cors.access:handle()
            test_utils.assert_true(result, "Should allow configured custom headers")
        end
    },
    
    -- Preflight request with custom headers
    {
        name = "Preflight with custom headers request",
        func = function()            
            test_utils.mock.set_headers({
                Origin = "https://example.com",
                ["Access-Control-Request-Method"] = "POST",
                ["Access-Control-Request-Headers"] = "Custom-Header-1, Custom-Header-2"
            })
            test_utils.mock.set_method("OPTIONS")
            
            
            cors.configure({
                allow_origins = {"https://example.com"},
                allow_headers = {"Custom-Header-1", "Custom-Header-2"},
                allow_methods = {"POST", "OPTIONS"}
            })

            -- Test access phase
            local ok, err = pcall(function()
                return cors.access:handle()
            end)
            
            -- Verify the error was from ngx.exit
            test_utils.assert_false(ok, "Should handle preflight and stop processing")
            test_utils.assert_matches(err, "^ngx%.exit%(204%)$", "Should return 204 status")
        end
    }
}

-- Cleanup function to run after each test
function _M.after_each()
    ngx.log(ngx.DEBUG, "Running after_each cleanup for: cors_test")
    test_utils.reset_state()
end

-- Cleanup function to run after all tests
function _M.after_all()
    ngx.log(ngx.DEBUG, "Running after_all cleanup for: cors_test")
    test_utils.reset_state()
end

return _M 