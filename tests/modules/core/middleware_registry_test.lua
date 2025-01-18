--- Test suite for middleware registry
-- @module tests.modules.core.middleware_registry_test
-- @description Tests for middleware registration and management

-- 1. Requires
local test_utils = require "tests.core.test_utils"
local middleware_registry = require "modules.core.middleware_registry"
local registry = require "modules.middleware.registry"

-- 2. Local helper functions
local function setup_test_environment()
    test_utils.reset_state()
end

local function create_test_middleware(name, phase)
    return {
        name = name,
        module = name,
        enabled = true,
        phase = phase or "access"
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
        name = "Test: Registry initialization and middleware registration",
        func = function()
            -- Register middlewares
            local ok = middleware_registry.register()
            test_utils.assert_equals(true, ok, "Registry should register middlewares successfully")
            
            -- Verify request_id middleware registration
            test_utils.assert_not_nil(registry.request_id, "Request ID middleware should be in registry")
            test_utils.assert_equals(true, registry.request_id.multi_phase, "Request ID should be multi-phase")
            test_utils.assert_equals(true, registry.request_id.enabled, "Request ID should be enabled")
            test_utils.assert_not_nil(registry.request_id.phases.access, "Request ID should have access phase")
            test_utils.assert_not_nil(registry.request_id.phases.header_filter, "Request ID should have header_filter phase")
            test_utils.assert_not_nil(registry.request_id.phases.log, "Request ID should have log phase")
            
            -- Verify phases
            local phases = middleware_registry.get_phases()
            test_utils.assert_not_nil(phases.access, "Access phase should be defined")
            test_utils.assert_not_nil(phases.content, "Content phase should be defined")
            test_utils.assert_not_nil(phases.header_filter, "Header filter phase should be defined")
            test_utils.assert_not_nil(phases.body_filter, "Body filter phase should be defined")
            test_utils.assert_not_nil(phases.log, "Log phase should be defined")
        end
    },
    {
        name = "Test: Registry phase validation",
        func = function()
            -- Try to register middleware with invalid phase
            local invalid_reg = {
                test = create_test_middleware("test", "invalid_phase")
            }
            
            local ok = pcall(function()
                for name, config in pairs(invalid_reg) do
                    middleware_registry.register_middleware(name, config)
                end
            end)
            
            test_utils.assert_equals(false, ok, "Registry should reject invalid phases")
        end
    }
}

return _M