local _M = {}

local config_utils = require "config.utils"

-- Default values
local defaults = {
    buffer_size = "4k",
    flush_interval = "1s"
}

-- Initialize configuration
function _M.init()
    _M.buffer_size = config_utils.get_env("LOG_BUFFER_SIZE", defaults.buffer_size, "string")
    _M.flush_interval = config_utils.get_env("LOG_FLUSH_INTERVAL", defaults.flush_interval, "string")

    -- Log the configuration
    ngx.log(ngx.INFO, "Logging Configuration:")
    ngx.log(ngx.INFO, string.format("  - Buffer size: %s", _M.buffer_size))
    ngx.log(ngx.INFO, string.format("  - Flush interval: %s", _M.flush_interval))
end

return _M 