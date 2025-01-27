local test_runner = require "modules.test.test_runner"
local cors = require "middleware.cors.cors_main"
local cors_config = require "middleware.cors.cors_config"
local cjson = require "cjson"

local _M = {}

-- Setup function to run before all tests
function _M.before_all()
    ngx.log(ngx.DEBUG, "Running before_all setup for: cors_test")
    
    -- First reset the state (this will flush shared dictionaries)
    test_runner.reset_state()
    
    -- Then set up CORS configuration in the shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        error("Failed to access config_cache shared dictionary")
    end
    
    -- Create test configuration
    local cors_config = {
        -- Required fields
        allow_protocols = "https",
        allow_origins = "https://example.com,https://*.trusted.com",
        allow_methods = "GET,POST,PUT,DELETE,OPTIONS",
        allow_headers = "content-type,authorization,x-custom-header",
        
        -- Optional fields
        expose_headers = "x-custom-response",
        common_headers = "host,accept,accept-encoding,accept-language,content-type,content-length,origin",
        max_age = 3600,
        allow_credentials = true,
        
        -- Validation settings
        validation_max_origin_length = 253,
        validation_max_subdomain_count = 10,
        validation_max_subdomain_length = 63
    }
    
    -- Log the configuration we're about to set
    ngx.log(ngx.DEBUG, "Setting CORS config: " .. cjson.encode(cors_config))
    
    local ok, err = config_cache:set("cors", cjson.encode(cors_config))
    if not ok then
        ngx.log(ngx.ERR, "Failed to set CORS config in shared dictionary: " .. (err or "unknown error"))
        error("Failed to set CORS config: " .. (err or "unknown error"))
    end
    
    -- Verify the configuration was set correctly
    local stored_config = config_cache:get("cors")
    if stored_config then
        ngx.log(ngx.DEBUG, "Stored CORS config: " .. stored_config)
    else
        ngx.log(ngx.ERR, "Failed to retrieve stored CORS config")
    end
    
    -- Finally initialize CORS with the configuration
    cors.init()
    
    -- Log the global CORS configuration after initialization
    ngx.log(ngx.DEBUG, "Global CORS config after init: " .. cjson.encode(cors_config.global))
    
    ngx.log(ngx.DEBUG, "CORS test setup completed successfully")
end

-- Setup function to run before each test
-- function _M.before_each()
--     ngx.log(ngx.DEBUG, "Running before_each setup for: cors_test")
--     test_runner.reset_state()
    
--     -- Re-set the CORS configuration after state reset
--     local config_cache = ngx.shared.config_cache
--     local cors_config = {
--         -- Required fields
--         allow_protocols = "https",
--         allow_origins = "https://example.com,https://*.trusted.com",
--         allow_methods = "GET,POST,PUT,DELETE,OPTIONS",
--         allow_headers = "content-type,authorization,x-custom-header",
        
--         -- Optional fields
--         expose_headers = "x-custom-response",
--         common_headers = "host,accept,accept-encoding,accept-language,content-type,content-length,origin",
--         max_age = 3600,
--         allow_credentials = true,
        
--         -- Validation settings
--         validation_max_origin_length = 253,
--         validation_max_subdomain_count = 10,
--         validation_max_subdomain_length = 63
--     }
    
--     local ok, err = config_cache:set("cors", cjson.encode(cors_config))
--     if not ok then
--         ngx.log(ngx.ERR, "Failed to set CORS config in shared dictionary: " .. (err or "unknown error"))
--         error("Failed to set CORS config: " .. (err or "unknown error"))
--     end

--     ngx.log(ngx.DEBUG, "ngx.status: " .. ngx.status)
--     ngx.log(ngx.DEBUG, "ngx.ctx: " .. cjson.encode(ngx.ctx))
--     ngx.log(ngx.DEBUG, "ngx.header: " .. cjson.encode(ngx.header))
-- end

_M.tests = {
    -- Basic functionality tests
    --[[
    {
        name = "Non-CORS request should pass through",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Non-CORS request should pass through access phase")
            test_runner.assert_equals(200, ngx.status, "Status should remain 200")
        end
    },
    --]]
    
    {
        name = "Valid CORS request should be processed correctly",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com"
            })
            
            -- Log the current CORS configuration
            local config_cache = ngx.shared.config_cache
            local stored_config = config_cache:get("cors")
            ngx.log(ngx.DEBUG, "Current CORS config: " .. tostring(stored_config))
            
            -- Log the request context
            ngx.log(ngx.DEBUG, "Request method: " .. ngx.req.get_method())
            ngx.log(ngx.DEBUG, "Request headers: " .. cjson.encode(ngx.req.get_headers()))
            
            -- Log global CORS config
            ngx.log(ngx.DEBUG, "Global CORS config: " .. cjson.encode(cors_config.global))
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Valid CORS request should pass through access phase")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Valid CORS request should pass through header filter phase")
            test_runner.assert_equals("https://example.com", ngx.header["Access-Control-Allow-Origin"], "Origin should be reflected")
            test_runner.assert_equals("true", ngx.header["Access-Control-Allow-Credentials"], "Credentials should be allowed")
        end
    },
    
    --[[
    -- Preflight request tests
    {
        name = "Valid preflight request should be handled correctly",
        func = function()
            test_runner.mock.set_method("OPTIONS")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com",
                ["Access-Control-Request-Method"] = "POST",
                ["Access-Control-Request-Headers"] = "content-type,authorization"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Preflight should exit in access phase")
            test_runner.assert_equals(204, ngx.status, "Preflight should return 204")
            test_runner.assert_equals("https://example.com", ngx.header["Access-Control-Allow-Origin"], "Origin should be reflected")
            test_runner.assert_equals("GET,POST,PUT,DELETE,OPTIONS", ngx.header["Access-Control-Allow-Methods"], "Methods should be listed")
            test_runner.assert_equals("3600", ngx.header["Access-Control-Max-Age"], "Max age should be set")
        end
    },
    
    -- Invalid CORS request tests
    {
        name = "CORS request with disallowed origin should be rejected",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://evil.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Request with invalid origin should be rejected")
            test_runner.assert_equals(403, ngx.status, "Should return 403 Forbidden")
        end
    },
    
    {
        name = "CORS request with invalid HTTP method should be rejected",
        func = function()
            test_runner.mock.set_method("PATCH")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Request with invalid method should be rejected")
            test_runner.assert_equals(403, ngx.status, "Should return 403 Forbidden")
        end
    },
    
    {
        name = "CORS request with invalid headers should be rejected",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com",
                ["X-Dangerous-Header"] = "value"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Request with invalid headers should be rejected")
            test_runner.assert_equals(403, ngx.status, "Should return 403 Forbidden")
        end
    },
    
    -- Wildcard origin tests
    {
        name = "CORS request from wildcard subdomain should be allowed",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://api.trusted.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Request from wildcard subdomain should be allowed")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            test_runner.assert_equals("https://api.trusted.com", ngx.header["Access-Control-Allow-Origin"], "Origin should be reflected")
        end
    },
    
    -- Security tests
    {
        name = "CORS request with malicious origin should be rejected",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "javascript:alert(1)"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Request with malicious origin should be rejected")
            test_runner.assert_equals(403, ngx.status, "Should return 403 Forbidden")
        end
    },
    
    {
        name = "CORS request with extremely long origin should be rejected",
        func = function()
            local long_origin = "https://" .. string.rep("a", 1000) .. ".com"
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = long_origin
            })
            
            local ok = cors.access.handle()
            test_runner.assert_false(ok, "Request with extremely long origin should be rejected")
            test_runner.assert_equals(403, ngx.status, "Should return 403 Forbidden")
        end
    },
    
    -- Header handling tests
    {
        name = "Vary header should be set correctly",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Access phase should succeed")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            test_runner.assert_matches(ngx.header["Vary"], "Origin", "Vary header should include Origin")
            test_runner.assert_matches(ngx.header["Vary"], "Access%-Control%-Request%-Method", "Vary header should include Access-Control-Request-Method")
        end
    },
    
    {
        name = "Exposed headers should be set correctly",
        func = function()
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/api/test")
            test_runner.mock.set_headers({
                ["Origin"] = "https://example.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Access phase should succeed")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            test_runner.assert_equals("x-custom-response", ngx.header["Access-Control-Expose-Headers"], "Expose-Headers should be set correctly")
        end
    },
    
    -- Route-specific configuration tests
    {
        name = "Route-specific CORS configuration should override global",
        func = function()
            -- Configure a route-specific CORS setting
            local route_config = {
                allow_origins = {"https://special.com"},
                allow_methods = {"GET"},
                allow_credentials = false
            }
            cors_config.update_route_config("/special", "GET", route_config)
            
            test_runner.mock.set_method("GET")
            test_runner.mock.set_uri("/special")
            test_runner.mock.set_headers({
                ["Origin"] = "https://special.com"
            })
            
            local ok = cors.access.handle()
            test_runner.assert_true(ok, "Access phase should succeed with route-specific config")
            
            ok = cors.header_filter.handle()
            test_runner.assert_true(ok, "Header filter should succeed")
            test_runner.assert_equals("https://special.com", ngx.header["Access-Control-Allow-Origin"], "Origin should be allowed by route config")
            test_runner.assert_nil(ngx.header["Access-Control-Allow-Credentials"], "Credentials should not be allowed per route config")
        end
    }
    --]]
}

-- -- Cleanup function to run after each test
-- function _M.after_each()
--     ngx.log(ngx.DEBUG, "Running after_each cleanup for: cors_test")
--     test_runner.reset_state()
--     cors.init()
-- end

-- Cleanup function to run after all tests
function _M.after_all()
    ngx.log(ngx.DEBUG, "Running after_all cleanup for: cors_test")
    test_runner.reset_state()
    cors.init()
end

return _M 