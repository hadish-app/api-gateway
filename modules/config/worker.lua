local _M = {}

local config_utils = require "config.utils"

-- Initialize configuration
function _M.init()
    _M.cleanup_interval = config_utils.get_env("WORKER_CLEANUP_INTERVAL", 3600, "number")

    -- Log the configuration
    ngx.log(ngx.INFO, "Worker Configuration:")
    ngx.log(ngx.INFO, string.format("  - Cleanup interval: %d seconds", _M.cleanup_interval))
end

return _M 