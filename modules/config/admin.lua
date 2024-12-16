local _M = {}

local config_utils = require "config.utils"

-- Initialize configuration
function _M.init()
    _M.url = config_utils.get_env("ADMIN_SERVICE_URL", nil, "string")

    -- Validate required configuration
    assert(_M.url, "ADMIN_SERVICE_URL must be set")

    -- Log the configuration
    ngx.log(ngx.INFO, "Admin Service Configuration:")
    ngx.log(ngx.INFO, string.format("  - URL: %s", _M.url))
end

return _M 