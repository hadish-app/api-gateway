-- Integration test for health check
local test_utils = require "tests.core.test_utils"
local health = require "modules.services.health"
local cjson = require "cjson"

local _M = {}

-- Mock ngx variables and functions for testing
local function setup_ngx_mock()
    -- Create mock shared dictionaries
    local mock_dict = {
        free_space = function() return 1024000 end,
        capacity = function() return 1048576 end,
        get_keys = function() return {"test_key1", "test_key2"} end
    }
    
    _G.ngx = _G.ngx or {}
    ngx.shared = {
        stats = mock_dict,
        metrics = mock_dict,
        rate_limit = mock_dict,
        ip_blacklist = mock_dict,
        config_cache = mock_dict,
        worker_events = mock_dict
    }
    
    -- Mock other ngx variables
    ngx.var = ngx.var or {
        connections_active = 100,
        connections_reading = 10,
        connections_writing = 20,
        connections_waiting = 70,
        hostname = "test-host",
        remote_addr = "192.168.1.1",
        request_method = "GET",
        request_uri = "/health",
        server_protocol = "HTTP/1.1",
        scheme = "http",
        host = "localhost"
    }
    
    ngx.worker = ngx.worker or {
        id = function() return 0 end,
        count = function() return 4 end,
        pid = function() return 1234 end
    }
    
    ngx.req = ngx.req or {
        start_time = function() return ngx.now() - 0.1 end  -- 100ms ago
    }
end

-- Helper function to validate health data structure
local function validate_health_data(data)
    -- Basic checks
    test_utils.assert_equals("table", type(data), "Health data should be a table")
    test_utils.assert_equals("string", type(data.status), "Status should be a string")
    test_utils.assert_equals("healthy", data.status, "Status should be 'healthy'")
    test_utils.assert_equals("number", type(data.timestamp), "Timestamp should be a number")
    test_utils.assert_equals(true, data.timestamp > 0, "Timestamp should be positive")
    test_utils.assert_equals("string", type(data.version), "Version should be a string")
    
    -- System metrics checks
    test_utils.assert_equals("table", type(data.system), "System metrics should be a table")
    test_utils.assert_equals("table", type(data.system.worker), "Worker info should be a table")
    test_utils.assert_equals("table", type(data.system.memory), "Memory info should be a table")
    test_utils.assert_equals("table", type(data.system.connections), "Connection info should be a table")
    
    -- Shared dictionaries checks
    test_utils.assert_equals("table", type(data.system.shared_dicts), "Shared dictionaries should be a table")
    
    -- Check each expected shared dictionary
    local expected_dicts = {"stats", "metrics", "rate_limit", "ip_blacklist", "config_cache", "worker_events"}
    for _, dict_name in ipairs(expected_dicts) do
        local dict = data.system.shared_dicts[dict_name]
        test_utils.assert_equals("table", type(dict), dict_name .. " dictionary should exist")
        if dict then
            test_utils.assert_equals("number", type(dict.free_space), dict_name .. " free_space should be a number")
            test_utils.assert_equals("number", type(dict.capacity), dict_name .. " capacity should be a number")
            test_utils.assert_equals("table", type(dict.keys), dict_name .. " keys should be a table")
        end
    end
    
    -- Performance metrics checks
    test_utils.assert_equals("table", type(data.performance), "Performance metrics should be a table")
    
    -- Request info checks
    test_utils.assert_equals("table", type(data.request), "Request info should be a table")
    
    -- Print the data for inspection
    ngx.say("Health data:")
    ngx.say(cjson.encode(data))
end

_M.tests = {
    {
        name = "Test: Health data generation",
        func = function()
            setup_ngx_mock()
            local data = health.get_health_data()
            validate_health_data(data)
        end
    }
}

return _M 