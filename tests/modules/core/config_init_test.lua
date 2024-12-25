-- Integration test for config initialization
local test_utils = require "tests.core.test_utils"
local config = require "core.config"

local _M = {}

-- Define test case
_M.tests = {
    {
        name = "Test 1: Configuration initialization",
        func = function()
            local ok, err, config_data = config.init()
            test_utils.assert_equals(true, ok, "Config initialization")
            if err then
                ngx.say("Error: " .. err)
            end
            if config_data then
                ngx.say("Loaded configuration data:")
                ngx.say(require("cjson").encode(config_data))
            end
        end
    }
}

return _M 