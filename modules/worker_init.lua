local M = {}

local ip_ban = require "ip_ban"
local utils = require "utils"
local config = require "config"

-- At the top of the file
local function validate_dependencies()
    local required_modules = {
        ip_ban = ip_ban,
        utils = utils,
        config = config
    }
    
    for name, module in pairs(required_modules) do
        if not module then
            ngx.log(ngx.ERR, string.format("Required module '%s' not loaded", name))
            return false
        end
    end
    return true
end

-- Periodic cleanup function
local function cleanup(premature)
    -- Exit if worker is being shut down
    if premature then return end

    ngx.log(ngx.INFO, "Starting scheduled cleanup...")
    
    -- Cleanup banned IPs with error handling
    local ok, err = pcall(ip_ban.cleanup_expired)
    if not ok then
        ngx.log(ngx.ERR, "Failed to cleanup banned IPs: ", err)
    end
    
    -- Log completion
    ngx.log(ngx.INFO, string.format("Cleanup completed at: %s", 
        utils.get_iso8601_timestamp(ngx.time())))
end

-- Initialize the worker
function M.init()
    if not validate_dependencies() then
        return false
    end
    -- Get configuration
    local cleanup_interval = config.worker.cleanup_interval
    
    -- Create timer for periodic cleanup
    local ok, err = ngx.timer.every(cleanup_interval, cleanup)
    if not ok then
        ngx.log(ngx.ERR, "Failed to create cleanup timer: ", err)
        return false
    end
    
    ngx.log(ngx.INFO, string.format(
        "Worker initialization complete. Cleanup scheduled every %d seconds",
        cleanup_interval
    ))
end

return M 