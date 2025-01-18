--- Test suite for service registry
-- @module tests.modules.core.service_registry_test
-- @description Tests for service registration and management

-- 1. Requires
local test_utils = require "tests.core.test_utils"
local service_registry = require "modules.core.service_registry"
local registry = require "modules.services.registry"

-- 2. Local helper functions
local function setup_test_environment()
    test_utils.reset_state()
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
        name = "Test: Service registry initialization and registration",
        func = function()
            -- Register services
            local ok = service_registry.register()
            test_utils.assert_equals(true, ok, "Service registry should register services successfully")
            
            -- Verify health service registration
            test_utils.assert_not_nil(registry.health, "Health service should be in registry")
            test_utils.assert_equals("modules.services.health", registry.health.module, "Health service should have correct module")
            
            -- Verify health service routes
            local health_routes = registry.health.routes
            test_utils.assert_not_nil(health_routes, "Health service should have routes")
            test_utils.assert_equals("/health", health_routes[1].path, "Health service should have /health route")
            test_utils.assert_equals("GET", health_routes[1].method, "Health service should have GET method")
            test_utils.assert_equals("check", health_routes[1].handler, "Health service should have check handler")
            
            test_utils.assert_equals("/health/details", health_routes[2].path, "Health service should have /health/details route")
            test_utils.assert_equals("GET", health_routes[2].method, "Health service should have GET method")
            test_utils.assert_equals("check_detailed", health_routes[2].handler, "Health service should have check_detailed handler")
        end
    }
}

return _M 