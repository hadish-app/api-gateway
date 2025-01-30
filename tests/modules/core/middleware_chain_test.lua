local test_runner = require "modules.test.test_runner"
local middleware_chain = require "modules.core.middleware_chain"

local _M = {}

-- Shared execution order table
local execution_order = {}

-- Helper function to reset state before each test
local function reset_state()
    ngx.log(ngx.DEBUG, "Middleware Chain Test: Resetting state")
    middleware_chain.reset()
    ngx.ctx = {}  -- Reset context
    ngx.header = {}  -- Reset response headers
    execution_order = {}
    ngx.log(ngx.DEBUG, "Middleware Chain Test: State reset complete")
end

-- Base middleware factory
local function create_base_middleware(name, priority, routes)
    return {
        name = name,
        priority = priority,
        routes = routes or {},
        execution_count = 0,
        
        handle = function(self)
            ngx.log(ngx.DEBUG, "Executing middleware: ", self.name)
            self.execution_count = self.execution_count + 1
            table.insert(execution_order, self.name)
            return self:process()
        end
    }
end

-- Test middleware factory
local function create_test_middleware(name, priority, routes)
    local m = create_base_middleware(name, priority, routes)
    m.process = function(self)
        return true
    end
    return m
end

local function create_failing_test_middleware(name, priority, routes) 
    local m = create_base_middleware(name, priority, routes)
    m.process = function(self)
        error("Intentional failure in " .. self.name)
    end
    return m
end

local function create_interrupting_test_middleware(name, priority, routes)
    local m = create_base_middleware(name, priority, routes)
    m.process = function(self)
        return false
    end
    return m
end

-- Add at the top of the file with other utility functions
local function reset_chain()
    -- Use the module's reset function
    middleware_chain.reset()
    -- Reset test-specific state
    execution_order = {}
end

_M.tests = {
    {
        name = "Basic middleware addition and execution",
        func = function()
            reset_state()
            
            -- Create and add middleware
            ngx.log(ngx.DEBUG, "Creating test middleware m1")
            local m1 = create_test_middleware("m1", 10)
            
            ngx.log(ngx.DEBUG, "Adding m1 to middleware chain")
            middleware_chain.use(m1, "m1")
            
            ngx.log(ngx.DEBUG, "Setting m1 state to active")
            middleware_chain.set_state("m1", true)
            
            -- Run chain
            ngx.log(ngx.DEBUG, "Running middleware chain")
            local result = middleware_chain.run("/")
            
            -- Verify first execution
            test_runner.assert_equals(true, result, "Chain should complete successfully")
            test_runner.assert_equals(1, m1.execution_count, "Middleware should execute once")

            -- Run chain again
            ngx.log(ngx.DEBUG, "Running middleware chain second time")
            result = middleware_chain.run("/")
            
            -- Verify second execution
            test_runner.assert_equals(true, result, "Chain should complete successfully on second run")
            test_runner.assert_equals(2, m1.execution_count, "Middleware should execute twice")
            
            -- Disable m1
            ngx.log(ngx.DEBUG, "Disabling m1")
            middleware_chain.set_state("m1", false)
            
            -- Run chain with disabled middleware
            ngx.log(ngx.DEBUG, "Running middleware chain with disabled m1")
            result = middleware_chain.run("/")
            
            -- Verify execution count didn't increase
            test_runner.assert_equals(true, result, "Chain should complete successfully with disabled middleware")
            test_runner.assert_equals(2, m1.execution_count, "Disabled middleware should not execute")

            -- Enable m1
            ngx.log(ngx.DEBUG, "Enabling m1")
            middleware_chain.set_state("m1", true)
            
            -- Run chain again with enabled middleware
            ngx.log(ngx.DEBUG, "Running middleware chain with enabled m1")
            result = middleware_chain.run("/")
            
            -- Verify execution count increased
            test_runner.assert_equals(true, result, "Chain should complete successfully with enabled middleware")
            test_runner.assert_equals(3, m1.execution_count, "Enabled middleware should execute")

            ngx.log(ngx.DEBUG, "Test completed. Result: ", result, ", Execution count: ", m1.execution_count)
            
            
        end
    },
    
    {
        name = "Priority ordering",
        func = function()
            reset_state()
            
            -- Create middleware with different priorities
            local m1 = create_test_middleware("m1", 50)
            local m2 = create_test_middleware("m2", 10) 
            local m3 = create_test_middleware("m3", 30)
            local m4 = create_test_middleware("m4", 20)
            local m5 = create_test_middleware("m5", 40)
            
            -- Add in random order to test priority sorting
            middleware_chain.use(m3, "m3") -- Priority 30
            middleware_chain.use(m1, "m1") -- Priority 50
            middleware_chain.use(m4, "m4") -- Priority 20
            middleware_chain.use(m2, "m2") -- Priority 10
            middleware_chain.use(m5, "m5") -- Priority 40
            
            -- Activate all middleware
            middleware_chain.set_state("m1", true)
            middleware_chain.set_state("m2", true)
            middleware_chain.set_state("m3", true)
            middleware_chain.set_state("m4", true)
            middleware_chain.set_state("m5", true)
            
            -- Run chain
            middleware_chain.run("/")
            
            -- Verify execution order based on priority (lowest to highest)
            test_runner.assert_equals("m2", execution_order[1], "M2 (priority 10) should execute first")
            test_runner.assert_equals("m4", execution_order[2], "M4 (priority 20) should execute second")
            test_runner.assert_equals("m3", execution_order[3], "M3 (priority 30) should execute third")
            test_runner.assert_equals("m5", execution_order[4], "M5 (priority 40) should execute fourth")
            test_runner.assert_equals("m1", execution_order[5], "M1 (priority 50) should execute last")
            
            
        end
    },
    
    {
        name = "Route-specific middleware",
        func = function()
            reset_state()
            
            -- Create global and route-specific middleware
            local global_m = create_test_middleware("global", 10)
            local admin_m = create_test_middleware("admin", 20, {"/admin"})
            local api_m = create_test_middleware("api", 20, {"/api"})
            
            -- Add all middleware
            middleware_chain.use(global_m, "global")
            middleware_chain.use(admin_m, "admin")
            middleware_chain.use(api_m, "api")
            
            -- Activate all
            middleware_chain.set_state("global", true)
            middleware_chain.set_state("admin", true)
            middleware_chain.set_state("api", true)
            
            -- Test admin route
            middleware_chain.run("/admin")
            test_runner.assert_equals(1, global_m.execution_count, "Global middleware should execute")
            test_runner.assert_equals(1, admin_m.execution_count, "Admin middleware should execute")
            test_runner.assert_equals(0, api_m.execution_count, "API middleware should not execute")
            
            -- Reset counts
            global_m.execution_count = 0
            admin_m.execution_count = 0
            api_m.execution_count = 0
            
            -- Test api route
            middleware_chain.run("/api")
            test_runner.assert_equals(1, global_m.execution_count, "Global middleware should execute")
            test_runner.assert_equals(0, admin_m.execution_count, "Admin middleware should not execute")
            test_runner.assert_equals(1, api_m.execution_count, "API middleware should execute")
            
            
        end
    },
    
    {
        name = "Middleware state management",
        func = function()
            reset_state()
            
            -- Create and add middleware
            local m1 = create_test_middleware("m1", 10)
            middleware_chain.use(m1, "m1")
            
            -- Test disabled state (default)
            middleware_chain.run("/")
            test_runner.assert_equals(0, m1.execution_count, "Disabled middleware should not execute")
            
            -- Test active state
            middleware_chain.set_state("m1", true)
            middleware_chain.run("/")
            test_runner.assert_equals(1, m1.execution_count, "Active middleware should execute")
            
            -- Test disabling again
            middleware_chain.set_state("m1", false)
            middleware_chain.run("/")
            test_runner.assert_equals(1, m1.execution_count, "Disabled middleware should not execute again")
            
            -- Test invalid state transition
            local ok, err = pcall(function()
                middleware_chain.set_state("m1", "INVALID_STATE")
            end)
            test_runner.assert_equals(false, ok, "Setting invalid state should fail")
            
            -- Test non-existent middleware
            ok, err = pcall(function() 
                middleware_chain.set_state("non_existent", true)
            end)
            test_runner.assert_equals(false, ok, "Setting state for non-existent middleware should fail")
            
            -- Test state persistence
            middleware_chain.set_state("m1", true)
            middleware_chain.run("/")
            test_runner.assert_equals(2, m1.execution_count, "State should persist between runs")
            
            -- Test multiple state changes
            middleware_chain.set_state("m1", false)
            middleware_chain.set_state("m1", true)
            middleware_chain.set_state("m1", false)
            middleware_chain.run("/")
            test_runner.assert_equals(2, m1.execution_count, "Final disabled state should be respected")
            
            
        end
    },
    
    {
        name = "Error handling",
        func = function()
            reset_state()
            
            local middleware_name = "failing_middleware"
            
            -- Create middleware that will fail
            local middleware = create_failing_test_middleware(middleware_name, 10)
            
            middleware_chain.use(middleware, middleware_name)
            middleware_chain.set_state(middleware_name, true)
            
            -- Debug log to verify middleware state
            ngx.log(ngx.DEBUG, "Testing middleware ", middleware_name, ", should_fail=", tostring(middleware.should_fail))
            
            -- Run chain and verify it throws an error
            local ok, err = pcall(function()
                middleware_chain.run("/")
            end)
            
            ngx.log(ngx.DEBUG, "pcall result: ok=", tostring(ok), ", err=", tostring(err))
            
            test_runner.assert_equals(false, ok, "Chain should throw an error")
            test_runner.assert_equals(true, string.match(tostring(err), "Middleware " .. middleware_name .. " failed") ~= nil,
                "Error should contain middleware failure message")
            
            
        end
    },
    
    {
        name = "Chain interruption",
        func = function()
            reset_state()
            
            -- Create middleware chain where middle one stops execution
            local m1 = create_test_middleware("m1", 10)
            local m2 = create_interrupting_test_middleware("m2", 20)
            local m3 = create_test_middleware("m3", 30)
            

            
            middleware_chain.use(m1, "m1")
            middleware_chain.use(m2, "m2")
            middleware_chain.use(m3, "m3")
            
            middleware_chain.set_state("m1", true)
            middleware_chain.set_state("m2", true)
            middleware_chain.set_state("m3", true)
            
            -- Run chain
            local result = middleware_chain.run("/")
            
            -- Verify
            test_runner.assert_equals(false, result, "Chain should return false when interrupted")
            test_runner.assert_equals(1, m1.execution_count, "First middleware should execute")
            test_runner.assert_equals(1, m2.execution_count, "Second middleware should execute")
            test_runner.assert_equals(0, m3.execution_count, "Third middleware should not execute")            
        end
    }
}

-- Add cleanup after all tests
function _M.after_all()
    ngx.log(ngx.NOTICE, "Middleware chain tests completed. Remember to restart the container to reset state.")
end

return _M