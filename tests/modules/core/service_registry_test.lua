--- Test suite for service registry
-- @module tests.modules.core.service_registry_test
-- @description Tests for service registration and management

-- 1. Requires
local test_runner = require "modules.test.test_runner"
local service_registry = require "modules.core.service_registry"

-- 2. Local helper functions
local function setup_test_environment()
    test_runner.reset_state()
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
        name = "Service registry initialization and registration",
        func = function()
            -- Register services
            local ok = service_registry.register()
            test_runner.assert_equals(true, ok, "Service registry should register services successfully")
            
        end
    }
}

return _M 