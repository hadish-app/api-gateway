local test_utils = require "tests.core.test_utils"
local phase_handlers = require "modules.core.phase_handlers"

local _M = {}

_M.tests = {
    {
        name = "Test: Init phase initialization and shared dictionary setup",
        func = function()
            -- Execute init phase
            local ok, err = phase_handlers.init()
            
            -- Verify successful initialization
            test_utils.assert_true(ok, "Init phase should succeed")
            test_utils.assert_nil(err, "No error should be present")
            
            -- Verify shared dictionaries are properly initialized
            test_utils.assert_not_nil(ngx.shared.stats, "Stats dictionary should exist")
            test_utils.assert_not_nil(ngx.shared.metrics, "Metrics dictionary should exist")
            test_utils.assert_not_nil(ngx.shared.config_cache, "Config cache dictionary should exist")
            test_utils.assert_not_nil(ngx.shared.rate_limit, "Rate limit dictionary should exist")
            
            -- Verify initial stats values
            local stats = ngx.shared.stats
            test_utils.assert_not_nil(stats:get("start_time"), "Start time should be set")
            test_utils.assert_equals(stats:get("total_requests"), 0, "Total requests should be initialized to 0")
            test_utils.assert_equals(stats:get("active_connections"), 0, "Active connections should be initialized to 0")
            
            -- Verify initial metrics values
            local metrics = ngx.shared.metrics
            test_utils.assert_equals(metrics:get("requests_per_second"), 0, "Requests per second should be initialized to 0")
            test_utils.assert_equals(metrics:get("average_response_time"), 0, "Average response time should be initialized to 0")
        end
    },
    {
        name = "Test: Init worker phase worker registration",
        func = function()
            -- Execute init worker phase
            local ok, err = phase_handlers.init_worker()
            
            -- Verify successful worker initialization
            test_utils.assert_true(ok, "Init worker phase should succeed")
            test_utils.assert_nil(err, "No error should be present")
            
            -- Verify worker registration in stats
            local stats = ngx.shared.stats
            local worker_id = ngx.worker.id()
            local worker_key = "worker:" .. worker_id .. ":start_time"
            
            local worker_start_time = stats:get(worker_key)
            ngx.log(ngx.DEBUG, "Worker start time: ", worker_start_time)
            test_utils.assert_not_nil(worker_start_time, "Worker start time should be recorded")
            test_utils.assert_type(worker_start_time, "number", "Worker start time should be a number")
        end
    }
}

return _M 