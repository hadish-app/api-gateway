local _M = {}

-- Import configuration modules
local rate_limit_config = require "config.rate_limit"
local ip_ban_config = require "config.ip_ban"
local logging_config = require "config.logging"
local admin_config = require "config.admin"
local worker_config = require "config.worker"

-- Initialize all configurations
function _M.init()
    -- Initialize each configuration module
    rate_limit_config.init()
    ip_ban_config.init()
    logging_config.init()
    admin_config.init()
    worker_config.init()

    -- Expose configurations
    _M.rate_limit = rate_limit_config
    _M.ip_ban = ip_ban_config
    _M.logging = logging_config
    _M.admin_service = admin_config
    _M.worker = worker_config
end

return _M 