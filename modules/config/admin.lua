local _M = {}

local config_utils = require "config.utils"

-- Default values
local defaults = {
    url = "http://localhost:3000"
}

-- Initialize configuration
function _M.init()
    _M.url = config_utils.get_env("ADMIN_SERVICE_URL", defaults.url, "string")

    -- Log the configuration
    ngx.log(ngx.INFO, "Admin Service Configuration:")
    ngx.log(ngx.INFO, string.format("  - URL: %s", _M.url))
end

return _M 