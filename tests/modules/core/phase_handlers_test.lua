local cjson = require "cjson"
local test_runner = require "modules.test.test_runner"
local phase_handlers = require "modules.core.phase_handlers"
local middleware_chain = require "modules.core.middleware_chain"
local middleware_registry = require "modules.core.middleware_registry"
local service_registry = require "modules.core.service_registry"

local _M = {}

local original_middleware_registry_register = nil
local original_service_registry_register = nil
local original_middleware_chain_run_chain = nil     

-- Mock dependencies
local function setup_mocks()
    ngx.log(ngx.DEBUG, "[TEST] Setting up test mocks")
    
    -- Mock middleware_registry
    ngx.log(ngx.DEBUG, "[TEST] Mocking middleware_registry.register")
    original_middleware_registry_register = middleware_registry.register
    middleware_registry.register = function()
        ngx.log(ngx.DEBUG, "[TEST] Called middleware_registry.register mock")
        return true
    end

    -- Mock service_registry
    ngx.log(ngx.DEBUG, "[TEST] Mocking service_registry.register")
    original_service_registry_register = service_registry.register
    service_registry.register = function()
        ngx.log(ngx.DEBUG, "[TEST] Called service_registry.register mock")
        return true
    end

    -- Mock middleware_chain
    ngx.log(ngx.DEBUG, "[TEST] Mocking middleware_chain.run_chain")
    original_middleware_chain_run_chain = middleware_chain.run_chain
    middleware_chain.run_chain = function(phase)
        ngx.log(ngx.DEBUG, "[TEST] Called middleware_chain.run_chain mock for phase: " .. phase)
        return true
    end
    
    ngx.log(ngx.DEBUG, "[TEST] Mock setup completed")
end

function teardown_mocks()
    ngx.log(ngx.DEBUG, "[TEST] Teardown mocks")
    -- Restore original functions
    middleware_registry.register = original_middleware_registry_register
    service_registry.register = original_service_registry_register
    middleware_chain.run_chain = original_middleware_chain_run_chain
end

_M.before_each = function()
    ngx.log(ngx.DEBUG, "[TEST] Executing before_each hook")
    test_runner.reset_state()
    setup_mocks()
    ngx.log(ngx.DEBUG, "[TEST] before_each hook completed")
end

_M.tests = {
    {
        name = "Test: Verify shared dictionaries initialization",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting shared dictionaries verification test")
            
            -- Execute init phase
            ngx.log(ngx.DEBUG, "[TEST] Executing init phase")
            local ok, err = phase_handlers.init()
            
            -- Verify successful initialization
            ngx.log(ngx.DEBUG, "[TEST] Verifying initialization result: ok=" .. tostring(ok) .. ", err=" .. tostring(err))
            test_runner.assert_true(ok, "Init phase should succeed")
            test_runner.assert_nil(err, "No error should be present")
            
            -- Verify all required shared dictionaries exist
            local required_dicts = {
                "stats", "metrics", "config_cache", "rate_limit",
                "ip_blacklist", "worker_events"
            }
            
            ngx.log(ngx.DEBUG, "[TEST] Verifying required shared dictionaries")
            for _, dict_name in ipairs(required_dicts) do
                ngx.log(ngx.DEBUG, "[TEST] Checking shared dictionary: " .. dict_name)
                test_runner.assert_not_nil(
                    ngx.shared[dict_name], 
                    "Shared dictionary '" .. dict_name .. "' should exist"
                )
            end
            
            ngx.log(ngx.DEBUG, "[TEST] Shared dictionaries verification test completed")
        end
    },
    {
        name = "Test: Initial shared state values",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting initial shared state values test")
            
            local ok = phase_handlers.init()
            test_runner.assert_true(ok, "Init should succeed")
            
            -- Verify stats initialization
            ngx.log(ngx.DEBUG, "[TEST] Verifying stats dictionary values")
            local stats = ngx.shared.stats
            test_runner.assert_not_nil(stats, "Stats dictionary should exist")

            local start_time = stats:get("start_time")
            ngx.log(ngx.DEBUG, "[TEST] Stats - start_time: " .. tostring(start_time))      
            test_runner.assert_not_nil(start_time, "Start time should be set")
            
            local total_requests = stats:get("total_requests")
            ngx.log(ngx.DEBUG, "[TEST] Stats - total_requests: " .. tostring(total_requests))
            test_runner.assert_equals(total_requests, 0, "Total requests should be initialized to 0")
            
            local active_connections = stats:get("active_connections")
            ngx.log(ngx.DEBUG, "[TEST] Stats - active_connections: " .. tostring(active_connections))
            test_runner.assert_equals(active_connections, 0, "Active connections should be initialized to 0")
            
            -- Verify metrics initialization
            ngx.log(ngx.DEBUG, "[TEST] Verifying metrics dictionary values")
            local metrics = ngx.shared.metrics
            test_runner.assert_not_nil(metrics, "Metrics dictionary should exist")
            
            local rps = metrics:get("requests_per_second")
            ngx.log(ngx.DEBUG, "[TEST] Metrics - requests_per_second: " .. tostring(rps))
            test_runner.assert_equals(rps, 0, "RPS should be initialized to 0")
            
            local avg_response_time = metrics:get("average_response_time")
            ngx.log(ngx.DEBUG, "[TEST] Metrics - average_response_time: " .. tostring(avg_response_time))
            test_runner.assert_equals(avg_response_time, 0, "Average response time should be initialized to 0")
            
            ngx.log(ngx.DEBUG, "[TEST] Initial shared state values test completed")
        end
    },
    {
        name = "Test: Config cache initialization",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting config cache initialization test")
            
            local ok = phase_handlers.init()
            test_runner.assert_true(ok, "Init should succeed")
            
            -- Verify config cache exists and is accessible
            ngx.log(ngx.DEBUG, "[TEST] Verifying config_cache dictionary")
            local config_cache = ngx.shared.config_cache
            test_runner.assert_not_nil(config_cache, "Config cache should exist")
            
            ngx.log(ngx.DEBUG, "[TEST] Config cache initialization test completed")
        end
    },
    {
        name = "Test: Worker initialization and registration",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting worker initialization test")
            
            -- Execute init worker phase
            ngx.log(ngx.DEBUG, "[TEST] Executing init_worker phase")
            local ok, err = phase_handlers.init_worker()
            
            -- Verify successful worker initialization
            ngx.log(ngx.DEBUG, "[TEST] Verifying worker initialization result: ok=" .. tostring(ok) .. ", err=" .. tostring(err))
            test_runner.assert_true(ok, "Init worker phase should succeed")
            test_runner.assert_nil(err, "No error should be present")
            
            -- Verify worker registration
            local stats = ngx.shared.stats
            local worker_id = ngx.worker.id()
            local worker_key = "worker:" .. worker_id .. ":start_time"
            
            ngx.log(ngx.DEBUG, "[TEST] Verifying worker registration for worker_id: " .. worker_id)
            local worker_start_time = stats:get(worker_key)
            ngx.log(ngx.DEBUG, "[TEST] Worker start_time: " .. tostring(worker_start_time))
            test_runner.assert_not_nil(worker_start_time, "Worker start time should be recorded")
            test_runner.assert_type(worker_start_time, "number", "Worker start time should be a number")
            
            ngx.log(ngx.DEBUG, "[TEST] Worker initialization test completed")
        end
    },
    {
        name = "Test: Standard phase handlers creation",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting standard phase handlers test")
            
            -- Test each standard phase handler
            local phases = {"access", "content", "header_filter", "body_filter", "log"}
            
            for _, phase in ipairs(phases) do
                ngx.log(ngx.DEBUG, "[TEST] Testing " .. phase .. " phase handler")
                test_runner.assert_not_nil(
                    phase_handlers[phase],
                    phase .. " phase handler should exist"
                )
                
                -- Execute the phase handler
                ngx.log(ngx.DEBUG, "[TEST] Executing " .. phase .. " phase handler")
                local ok, err = pcall(phase_handlers[phase])
                test_runner.assert_true(ok, phase .. " phase handler should execute without errors")
                if not ok then
                    ngx.log(ngx.ERR, "[TEST] Phase handler execution failed: " .. tostring(err))
                end
            end
            
            ngx.log(ngx.DEBUG, "[TEST] Standard phase handlers test completed")
        end
    },
    {
        name = "Test: Middleware registration failure handling",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting middleware registration failure test")
            
            -- Store original middleware registration function
            local original_register = middleware_registry.register
            
            -- Mock middleware registration failure
            ngx.log(ngx.DEBUG, "[TEST] Setting up middleware registration failure mock")
            middleware_registry.register = function()
                ngx.log(ngx.DEBUG, "[TEST] Simulating middleware registration failure")
                return false, "Mock middleware registration error"
            end
            
            -- Execute init phase   
            ngx.log(ngx.DEBUG, "[TEST] Executing init phase")
            local ok, err = phase_handlers.init()
            
            -- Verify initialization failure
            ngx.log(ngx.DEBUG, "[TEST] Verifying initialization failure: ok=" .. tostring(ok) .. ", err=" .. tostring(err))
            test_runner.assert_false(ok, "Init should fail when middleware registration fails")
            
            -- Restore original middleware registration
            ngx.log(ngx.DEBUG, "[TEST] Restoring original middleware registration")
            middleware_registry.register = original_register
            
            ngx.log(ngx.DEBUG, "[TEST] Middleware registration failure test completed")
        end
    },
    {
        name = "Test: Service registration failure handling",
        func = function()
            ngx.log(ngx.DEBUG, "[TEST] Starting service registration failure test")
            
            -- Mock service registration failure
            ngx.log(ngx.DEBUG, "[TEST] Setting up service registration failure mock")
            service_registry.register = function()
                ngx.log(ngx.DEBUG, "[TEST] Simulating service registration failure")
                return false, "Mock service registration error"
            end
            
            local ok = phase_handlers.init()
            test_runner.assert_false(ok, "Init should fail when service registration fails")
            
            ngx.log(ngx.DEBUG, "[TEST] Service registration failure test completed")
        end
    }
}

_M.after_each = function()
    ngx.log(ngx.DEBUG, "[TEST] Executing after_each hook")
    teardown_mocks()
    test_runner.reset_state()

    ngx.log(ngx.DEBUG, "[TEST] after_each hook completed")
end

return _M 