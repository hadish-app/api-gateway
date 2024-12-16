local _M = {}

local config_utils = require "config.utils"

-- Initialize configuration
function _M.init()
    _M.duration = config_utils.get_env("BAN_DURATION_SECONDS", nil, "number")
    _M.file_path = config_utils.get_env("BANNED_IPS_FILE", nil, "string")

    -- Validate required configuration
    assert(_M.duration, "BAN_DURATION_SECONDS must be set")
    assert(_M.file_path, "BANNED_IPS_FILE must be set")

    -- Log the configuration
    ngx.log(ngx.INFO, "IP Ban Configuration:")
    ngx.log(ngx.INFO, string.format("  - Duration: %d seconds", _M.duration))
    ngx.log(ngx.INFO, string.format("  - File path: %s", _M.file_path))
end

return _M 