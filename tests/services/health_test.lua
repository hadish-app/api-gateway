-- Integration test for health check
local test_runner = require "modules.test.test_runner"
local health = require "services.health"
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

-- Helper function to validate basic health data structure
local function validate_basic_health(data)
    -- Basic checks
    test_runner.assert_equals("table", type(data), "Health data should be a table")
    test_runner.assert_equals("string", type(data.status), "Status should be a string")
    test_runner.assert_equals("healthy", data.status, "Status should be 'healthy'")
    test_runner.assert_equals("number", type(data.timestamp), "Timestamp should be a number")
    test_runner.assert_equals(true, data.timestamp > 0, "Timestamp should be positive")
    test_runner.assert_equals("string", type(data.version), "Version should be a string")
    
    -- System metrics checks
    test_runner.assert_equals("table", type(data.system), "System metrics should be a table")
    test_runner.assert_equals("table", type(data.system.memory), "Memory info should be a table")
    test_runner.assert_equals("number", type(data.system.memory.lua_used), "Lua memory usage should be a number")
    test_runner.assert_equals("table", type(data.system.connections), "Connection info should be a table")
    test_runner.assert_equals("string", type(data.system.connections.active), "Active connections should exist")
    test_runner.assert_equals("string", type(data.system.connections.writing), "Writing connections should exist")
    
    -- Performance checks
    test_runner.assert_equals("table", type(data.performance), "Performance metrics should be a table")
    test_runner.assert_equals("number", type(data.performance.request_time), "Request time should be a number")
end

-- Helper function to validate detailed health data structure
local function validate_detailed_health(data)
    -- Basic checks
    test_runner.assert_equals("string", type(data.status), "Status should be a string")
    test_runner.assert_equals("healthy", data.status, "Status should be 'healthy'")
    test_runner.assert_equals("number", type(data.timestamp), "Timestamp should be a number")
    test_runner.assert_equals("string", type(data.version), "Version should be a string")

    -- System checks
    test_runner.assert_equals("table", type(data.system), "System should be a table")
    test_runner.assert_equals("string", type(data.system.hostname), "Hostname should be a string")

    -- Memory checks
    test_runner.assert_equals("table", type(data.system.memory), "Memory should be a table")
    test_runner.assert_equals("number", type(data.system.memory.lua_used), "Lua used memory should be a number")
    test_runner.assert_equals("number", type(data.system.memory.lua_used_mb), "Lua used MB should be a number")

    -- Connection checks
    test_runner.assert_equals("table", type(data.system.connections), "Connections should be a table")
    test_runner.assert_equals("number", type(data.system.connections.active), "Active connections should be a number")
    test_runner.assert_equals("number", type(data.system.connections.reading), "Reading connections should be a number")
    test_runner.assert_equals("number", type(data.system.connections.writing), "Writing connections should be a number")
    test_runner.assert_equals("number", type(data.system.connections.waiting), "Waiting connections should be a number")

    -- Workers checks
    test_runner.assert_equals("table", type(data.system.worker), "Workers should be a table")
    test_runner.assert_equals("number", type(data.system.worker.count), "Worker count should be a number")

    -- Shared dictionaries checks
    test_runner.assert_equals("table", type(data.system.shared_dicts), "Shared dictionaries should be a table")
    local expected_dicts = {"stats", "metrics", "rate_limit", "ip_blacklist", "config_cache", "worker_events"}
    for _, dict_name in ipairs(expected_dicts) do
        local dict = data.system.shared_dicts[dict_name]
        test_runner.assert_equals("table", type(dict), dict_name .. " dictionary should be a table")
        test_runner.assert_equals("number", type(dict.free_space), dict_name .. " free space should be a number")
        test_runner.assert_equals("number", type(dict.capacity), dict_name .. " capacity should be a number") 
        test_runner.assert_equals("number", type(dict.utilization), dict_name .. " utilization should be a number")
        test_runner.assert_equals("table", type(dict.keys), dict_name .. " keys should be a table")
    end

    -- Performance checks
    test_runner.assert_equals("table", type(data.performance), "Performance should be a table")
    test_runner.assert_equals("number", type(data.performance.request_time), "Request time should be a number")
    test_runner.assert_equals("table", type(data.performance.request), "Request info should be a table")

    -- Request details checks
    local req = data.performance.request
    test_runner.assert_equals("string", type(req.host), "Request host should be a string")
    test_runner.assert_equals("string", type(req.remote_addr), "Remote address should be a string")
    test_runner.assert_equals("string", type(req.request_method), "Request method should be a string")
    test_runner.assert_equals("string", type(req.request_uri), "Request URI should be a string")
    test_runner.assert_equals("string", type(req.scheme), "Scheme should be a string")
end

_M.tests = {
    {
        name = "Test: Basic health check",
        func = function()
            local data = health.get_basic_health()
            validate_basic_health(data)
            ngx.say("Basic health data:")
            ngx.say(cjson.encode(data))
        end
    },
    {
        name = "Test: Detailed health check",
        func = function()
            local data = health.get_detailed_health()
            validate_detailed_health(data)
            ngx.say("Detailed health data:")
            ngx.say(cjson.encode(data))
        end
    },
}

return _M 