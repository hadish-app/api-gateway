local test_utils = require "tests.core.test_utils"
local middleware_chain = require "modules.core.middleware_chain"
local method_validator = require "modules.middleware.request.validations.method_validator"

local _M = {}

-- Helper function to reset test state
local function reset_state()
    ngx.ctx = {}
    ngx.var = ngx.var or {}
end

_M.tests = {
    {
        name = "Test: Valid HTTP methods",
        func = function()
            reset_state()
            
            -- Test each valid HTTP method
            local valid_methods = {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"}
            
            for _, method in ipairs(valid_methods) do
                ngx.var.request_method = method
                local result = method_validator:handle()
                test_utils.assert_equals(true, result, method .. " should be allowed")
            end
        end
    },
    {
        name = "Test: Invalid HTTP method",
        func = function()
            reset_state()
            
            -- Test an invalid method
            ngx.var.request_method = "INVALID"
            local result = method_validator:handle()
            test_utils.assert_equals(false, result, "Invalid method should be rejected")
            test_utils.assert_equals(405, ngx.status, "Should set 405 Method Not Allowed status")
        end
    },
    {
        name = "Test: Method override through header",
        func = function()
            reset_state()
            
            -- Setup request with override header
            ngx.var.request_method = "POST"
            ngx.req.get_headers = function()
                return { ["X-HTTP-Method-Override"] = "PUT" }
            end
            
            local result = method_validator:handle()
            test_utils.assert_equals(true, result, "Valid method override should be allowed")
            test_utils.assert_equals("PUT", ngx.ctx.original_request_method, "Original method should be stored")
        end
    },
    {
        name = "Test: Invalid method override",
        func = function()
            reset_state()
            
            -- Setup request with invalid override header
            ngx.var.request_method = "POST"
            ngx.req.get_headers = function()
                return { ["X-HTTP-Method-Override"] = "INVALID" }
            end
            
            local result = method_validator:handle()
            test_utils.assert_equals(false, result, "Invalid method override should be rejected")
            test_utils.assert_equals(405, ngx.status, "Should set 405 Method Not Allowed status")
        end
    }
}

return _M 