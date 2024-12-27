local test_utils = require "tests.core.test_utils"
local middleware_chain = require "modules.core.middleware_chain"
local middleware_registry = require "modules.core.middleware_registry"
local request_id = require "modules.middleware.request_id"

local _M = {}

-- Helper function to reset state before each test
local function reset_state()
    ngx.log(ngx.DEBUG, "Request ID Test: Resetting state")
    middleware_chain.reset()
    ngx.ctx = {}  -- Reset context
    ngx.header = {}  -- Reset response headers
    
    -- Re-register middleware using registry
    local ok, err = middleware_registry.register()
    if not ok then
        error("Failed to register middleware: " .. tostring(err))
    end
    
    ngx.log(ngx.DEBUG, "Request ID Test: State reset complete")
end

_M.tests = {
    {
        name = "Test: Request ID generation",
        func = function()
            ngx.log(ngx.DEBUG, "Request ID Test: Starting request ID generation test")
            reset_state()
            
            -- Debug middleware state
            local chain = middleware_chain.get_chain("/")
            ngx.log(ngx.DEBUG, "Request ID Test: Chain length: ", #chain)
            for i, m in ipairs(chain) do
                ngx.log(ngx.DEBUG, "Request ID Test: Middleware[", i, "]: name=", m.name, 
                       ", state=", m.state)
            end
            
            -- Run middleware chain
            ngx.log(ngx.DEBUG, "Request ID Test: Running middleware chain")
            local result = middleware_chain.run("/")
            ngx.log(ngx.DEBUG, "Request ID Test: Middleware chain result: ", result)
            
            -- Debug current state
            ngx.log(ngx.DEBUG, "Request ID Test: Current context request_id: ", ngx.ctx.request_id or "nil")
            ngx.log(ngx.DEBUG, "Request ID Test: Current header X-Request-ID: ", 
                   ngx.header["X-Request-ID"] or "nil")
            
            -- Verify
            test_utils.assert_equals(true, result, "Chain should complete successfully")
            test_utils.assert_not_nil(ngx.ctx.request_id, "Request ID should be generated")
            test_utils.assert_not_nil(ngx.header["X-Request-ID"], "Request ID header should be set")
            test_utils.assert_equals(ngx.ctx.request_id, ngx.header["X-Request-ID"], 
                "Context and header should have same request ID")
            
            ngx.log(ngx.DEBUG, "Request ID Test: Request ID generation test completed")
        end
    },
    
    -- {
    --     name = "Test: Existing request ID",
    --     func = function()
    --         reset_state()
            
    --         -- Set incoming request ID
    --         local existing_id = "test-request-id-123"
    --         ngx.req.get_headers = function()
    --             return { ["X-Request-ID"] = existing_id }
    --         end
            
    --         -- Run middleware chain
    --         local result = middleware_chain.run("/")
            
    --         -- Verify
    --         test_utils.assert_equals(true, result, "Chain should complete successfully")
    --         test_utils.assert_equals(existing_id, ngx.ctx.request_id, 
    --             "Existing request ID should be preserved")
    --         test_utils.assert_equals(existing_id, ngx.header["X-Request-ID"], 
    --             "Existing request ID should be set in response header")
    --     end
    -- },
    
    -- {
    --     name = "Test: Disabled generation",
    --     func = function()
    --         reset_state()
            
    --         -- Disable request ID generation
    --         request_id.config.generate_if_missing = false
            
    --         -- Run middleware chain
    --         local result = middleware_chain.run("/")
            
    --         -- Verify
    --         test_utils.assert_equals(true, result, "Chain should complete successfully")
    --         test_utils.assert_nil(ngx.ctx.request_id, "Request ID should not be generated")
    --         test_utils.assert_nil(ngx.header["X-Request-ID"], "Request ID header should not be set")
            
    --         -- Reset configuration
    --         request_id.config.generate_if_missing = true
    --     end
    -- },
    
    -- {
    --     name = "Test: Custom configuration",
    --     func = function()
    --         reset_state()
            
    --         -- Set custom configuration
    --         local original_header = request_id.config.header_name
    --         local original_key = request_id.config.context_key
            
    --         request_id.config.header_name = "X-Custom-Request-ID"
    --         request_id.config.context_key = "custom_request_id"
            
    --         -- Run middleware chain
    --         local result = middleware_chain.run("/")
            
    --         -- Verify
    --         test_utils.assert_equals(true, result, "Chain should complete successfully")
    --         test_utils.assert_not_nil(ngx.ctx.custom_request_id, "Request ID should be in custom context key")
    --         test_utils.assert_not_nil(ngx.header["X-Custom-Request-ID"], "Custom header should be set")
    --         test_utils.assert_equals(ngx.ctx.custom_request_id, ngx.header["X-Custom-Request-ID"],
    --             "Context and header should have same request ID")
            
    --         -- Reset configuration
    --         request_id.config.header_name = original_header
    --         request_id.config.context_key = original_key
    --     end
    -- },
    
    -- {
    --     name = "Test: Helper function",
    --     func = function()
    --         reset_state()
            
    --         -- Run middleware chain
    --         middleware_chain.run("/")
            
    --         -- Verify helper function
    --         local id_from_helper = request_id:get()
    --         test_utils.assert_not_nil(id_from_helper, "Helper should return request ID")
    --         test_utils.assert_equals(ngx.ctx.request_id, id_from_helper,
    --             "Helper should return same ID as context")
    --     end
    -- }
}

return _M 