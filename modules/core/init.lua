-- Core Initialization Module
local _M = {}

-- Local references
local ngx = ngx
local shared = ngx.shared
local timer_every = ngx.timer.every
local log = ngx.log
local INFO = ngx.INFO
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local WARN = ngx.WARN

-- Import modules
local config = require "core.config"
local middleware_registry = require "modules.middleware.registry"
local middleware_chain = require "modules.core.middleware_chain"

-- Configuration
local SHARED_DICTS = {
    required = {
        "stats",         -- Runtime statistics
        "metrics",       -- Performance metrics
        "config_cache",  -- Configuration cache
        "rate_limit",    -- Rate limiting
        "ip_blacklist", -- IP blocking list
        "worker_events" -- Worker events
    },
    cleanup = {
        "stats",
        "metrics", "rate_limit", "config_cache"
    }
}

-- Verify shared dictionaries
local function verify_shared_dicts()
    log(INFO, "Starting shared dictionary verification...")
    
    -- List all available shared dictionaries
    local available_dicts = {}
    for dict_name, _ in pairs(shared) do
        available_dicts[dict_name] = true
        log(DEBUG, "Found shared dictionary: " .. dict_name)
    end
    
    
    for _, dict_name in ipairs(SHARED_DICTS.required) do
        if not shared[dict_name] then
            log(ERR, "Required shared dictionary not found: " .. dict_name)
            log(INFO, "Available dictionaries: " .. table.concat(available_dicts, ", "))
            return false
        end
        log(INFO, "Verified shared dictionary: " .. dict_name)
    end
    return true
end


-- Initialize shared states
local function init_shared_states()
    -- Initialize basic states
    local stats = shared.stats
    if not stats then
        return nil, "Failed to access stats dictionary"
    end

    local ok, err = pcall(function()
        stats:set("start_time", ngx.now())
        stats:set("total_requests", 0)
        stats:set("active_connections", 0)

        local metrics = shared.metrics
        metrics:set("requests_per_second", 0)
        metrics:set("average_response_time", 0)
    end)

    if not ok then
        log(ERR, "Failed to initialize shared states: " .. err)
        return nil, "Failed to initialize shared states: " .. err
    end

    return true
end

-- Bootstrap: Load required core libraries
local function bootstrap()
    log(INFO, "Starting bootstrap process...")
    
    -- Verify shared dictionaries
    if not verify_shared_dicts() then
        return nil, "Failed to verify shared dictionaries"
    end

    if not init_shared_states() then
        return nil, "Failed to initialize shared states"
    end
    
    -- Initialize configuration
    log(INFO, "Initializing configuration...")
    ok, err = config.init()
    if not ok then
        log(ERR, "Configuration initialization failed: " .. err)
        return nil, "Failed to initialize configuration: " .. err
    end
    log(INFO, "Configuration initialized successfully")
    
    -- Register middlewares
    local ok, err = middleware_registry.register()
    if not ok then
        log(ERR, "Middleware registration failed: " .. err)
        return nil, "Failed to register middlewares: " .. err
    end
    log(INFO, "Middlewares registered successfully")
    
    return true
end


-- Application startup
function _M.start()
    -- Step 1: Bootstrap the application
    local ok, err = bootstrap()
    if not ok then
        return nil, err
    end

    log(INFO, "Application initialized successfully")
    return true
end

-- Worker process initialization
function _M.start_worker()
    -- Get cleanup interval from config
    local cleanup_interval = config.get("system", "cleanup_interval")

    log(INFO, "Cleanup interval: " .. cleanup_interval)

    if not cleanup_interval or cleanup_interval < 1 then
        log(ERR, "Invalid cleanup_interval configuration. Must be >= 1")
        return nil, "Invalid cleanup_interval configuration. Must be >= 1"
    end

    -- Set up state cleanup timer
    local ok, err = timer_every(cleanup_interval, function(premature)
        if premature then return end
        
        -- Cleanup expired entries in all shared states
        for _, dict_name in ipairs(SHARED_DICTS.cleanup) do
            local dict = shared[dict_name]
            if dict then
                dict:flush_expired()
            end
        end
    end)

    if not ok then
        log(ERR, "Failed to create cleanup timer: " .. err)
        return nil, "Failed to create cleanup timer: " .. err
    end

    log(INFO, "Worker initialized successfully with cleanup interval: " .. cleanup_interval)
    return true
end

return _M