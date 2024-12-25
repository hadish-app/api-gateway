-- Integration tests for config module
local test_utils = require "tests.core.test_utils"
local config = require "core.config"
local env = require "utils.env"
local cjson = require "cjson"

local _M = {}

-- Define test cases
_M.tests = {
    {
        name = "Test 1: Configuration initialization",
        func = function()
            local ok, err = config.init()
            test_utils.assert_equals(true, ok, "Config initialization")
            if err then
                ngx.say("Error: " .. err)
            end
        end
    },
    {
        name = "Test 2: Environment loading",
        func = function()
            local env_config = env.load_all()
            test_utils.assert_equals("table", type(env_config), "Environment configuration loaded")
            if type(env_config) == "table" then
                ngx.say("Loaded configuration:")
                ngx.say(cjson.encode(env_config))
            end
        end
    },
    {
        name = "Test 3: Get configuration values",
        func = function()
            local server_port = config.get("server", "port")
            test_utils.assert_equals("8080", server_port, "Server port configuration")

            local logging_level = config.get("logging", "level")
            test_utils.assert_equals("notice", logging_level, "Logging level configuration")
        end
    },
    {
        name = "Test 4: Get configuration section",
        func = function()
            local server_config = config.get_section("server")
            test_utils.assert_equals("table", type(server_config), "Server configuration section")
            if type(server_config) == "table" then
                ngx.say("Server configuration:")
                ngx.say(cjson.encode(server_config))
                test_utils.assert_equals("8080", server_config.port, "Server port in section")
                test_utils.assert_equals("auto", server_config.worker_processes, "Worker processes in section")
            end
        end
    },
    {
        name = "Test 5: Set and get configuration value",
        func = function()
            local test_value = "test_value_" .. ngx.time()
            local ok, err = config.set("server", "test_key", test_value)
            test_utils.assert_equals(true, ok, "Set configuration value")
            if err then
                ngx.say("Error: " .. err)
            end

            local retrieved_value = config.get("server", "test_key")
            test_utils.assert_equals(test_value, retrieved_value, "Retrieved set configuration value")
        end
    }
}

return _M 