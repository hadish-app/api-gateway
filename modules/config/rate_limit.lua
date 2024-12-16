local _M = {}

local config_utils = require "config.utils"

-- Initialize configuration
function _M.init()
    _M.requests_per_second = config_utils.get_env("RATE_LIMIT_REQUESTS", nil, "number")
    _M.burst = config_utils.get_env("RATE_LIMIT_BURST", nil, "number")
    _M.violations_before_ban = config_utils.get_env("MAX_RATE_LIMIT_VIOLATIONS", nil, "number")
    _M.violation_expiry = config_utils.get_env("RATE_LIMIT_WINDOW", nil, "number")

    -- Validate required configuration
    assert(_M.requests_per_second, "RATE_LIMIT_REQUESTS must be set")
    assert(_M.burst, "RATE_LIMIT_BURST must be set")
    assert(_M.violations_before_ban, "MAX_RATE_LIMIT_VIOLATIONS must be set")
    assert(_M.violation_expiry, "RATE_LIMIT_WINDOW must be set")

    -- Log the configuration
    ngx.log(ngx.INFO, "Rate Limiting Configuration:")
    ngx.log(ngx.INFO, string.format("  - Requests per second: %d", _M.requests_per_second))
    ngx.log(ngx.INFO, string.format("  - Burst: %d", _M.burst))
    ngx.log(ngx.INFO, string.format("  - Violations before ban: %d", _M.violations_before_ban))
    ngx.log(ngx.INFO, string.format("  - Violation expiry: %d seconds", _M.violation_expiry))
end

return _M 