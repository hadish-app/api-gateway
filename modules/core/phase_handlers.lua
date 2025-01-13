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
local middleware_chain = require("modules.core.middleware_chain")
local middleware_registry = require("modules.middleware.registry")

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
        "metrics",
        "rate_limit",
        "config_cache"
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
        -- Clear any existing worker start times
        local keys = stats:get_keys(0)
        for _, key in ipairs(keys) do
            if key:match("^worker:%d+:start_time$") then
                stats:delete(key)
            end
        end

        stats:set("start_time", ngx.now())
        stats:set("total_requests", 0)
        stats:set("active_connections", 0)

        local metrics = shared.metrics
        metrics:set("requests_per_second", 0)
        metrics:set("average_response_time", 0)
    end)

    if not ok then
        log(ERR, "Failed to initialize shared states: " .. err)
        return nil, err
    end

    return true
end

-- Init phase handler
function _M.init()
    log(INFO, "Starting initialization phase...")
    
    -- Verify shared dictionaries
    if not verify_shared_dicts() then
        return nil, "Failed to verify shared dictionaries"
    end

    -- Initialize shared states
    local ok, err = init_shared_states()
    if not ok then
        return nil, "Failed to initialize shared states: " .. err
    end
    
    -- Register middlewares
    ngx.log(ngx.DEBUG, "Registering middlewares")
    local ok, err = middleware_registry.register()
    if not ok then
        log(ERR, "Middleware registration failed: " .. err)
        return nil, "Failed to register middlewares: " .. err
    end
    
    log(INFO, "Initialization phase completed successfully")
    return true
end

-- Init worker phase handler
function _M.init_worker()
    log(INFO, "Starting worker initialization phase...")
    
    -- Store worker start time with microsecond precision
    local worker_id = ngx.worker.id()
    local stats = shared.stats
    if not stats then
        log(ERR, "Stats dictionary not available during worker initialization")
        return nil, "Stats dictionary not available"
    end
    
    -- Log initial worker state
    log(DEBUG, string.format("Worker %d initial state - PID: %d, Memory: %.2fKB", 
        worker_id, 
        ngx.worker.pid(),
        collectgarbage("count")
    ))
    
    -- Log shared dictionary initial state
    log(DEBUG, string.format("Shared dict 'stats' initial state - Free: %d, Capacity: %d, Keys: %d",
        stats:free_space(),
        stats:capacity(),
        #stats:get_keys(0)
    ))
    
    -- Use worker pid and timestamp for more uniqueness    
    local worker_pid = ngx.worker.pid()
    local worker_key = "worker:" .. worker_id .. ":start_time"
    
    -- Get a fresh timestamp for this worker
    local start_time = ngx.now()
    
    -- Try to set only if not already set (avoid overwriting)
    local success, err = stats:safe_set(worker_key, start_time, 3600)  -- Expire after 1 hour
    if not success then
        if err == "exists" then
            local existing = stats:get(worker_key)
            log(DEBUG, string.format("Worker %d start time already set to %.6f", 
                worker_id, existing))
        else
            log(ERR, "Failed to store worker start time: " .. (err or "unknown error"))
            return nil, "Failed to store worker start time"
        end
    else
        log(INFO, string.format("Stored start time for worker %d (PID: %d): %.6f", 
            worker_id, worker_pid, start_time))
    end
    
    -- Verify the stored value
    local stored = stats:get(worker_key)
    if stored then
        log(DEBUG, string.format("Verified worker %d start time: %.6f", worker_id, stored))
        
        -- Log detailed worker state after initialization
        log(DEBUG, string.format("Worker %d final state - PID: %d, Start Time: %.6f, Memory: %.2fKB", 
            worker_id, 
            worker_pid, 
            stored,
            collectgarbage("count")
        ))
        
        -- Log shared dictionary final state
        log(DEBUG, string.format("Shared dict 'stats' final state - Free: %d, Capacity: %d, Keys: %d",
            stats:free_space(),
            stats:capacity(),
            #stats:get_keys(0)
        ))
    else
        log(ERR, string.format("Failed to verify worker %d start time", worker_id))
    end

    log(INFO, "Worker initialization completed successfully")
    return true
end

-- Access phase handler
function _M.access()
    ngx.log(ngx.DEBUG, "Access phase handler started")
    local result = middleware_chain.run_chain("access")
    ngx.log(ngx.DEBUG, "Access phase handler completed")
    return result
end

-- Content phase handler
function _M.content()
    ngx.log(ngx.DEBUG, "Content phase handler started")
    local result = middleware_chain.run_chain("content")
    ngx.log(ngx.DEBUG, "Content phase handler completed")
    return result
end

-- Header filter phase handler
function _M.header_filter()
    ngx.log(ngx.DEBUG, "Header filter phase handler started")
    local result = middleware_chain.run_chain("header_filter")
    ngx.log(ngx.DEBUG, "Header filter phase handler completed")
    return result
end

-- Body filter phase handler
function _M.body_filter()
    ngx.log(ngx.DEBUG, "Body filter phase handler started")
    local result = middleware_chain.run_chain("body_filter")
    ngx.log(ngx.DEBUG, "Body filter phase handler completed")
    return result
end

-- Log phase handler
function _M.log()
    ngx.log(ngx.DEBUG, "Log phase handler started")
    local result = middleware_chain.run_chain("log")
    ngx.log(ngx.DEBUG, "Log phase handler completed")
    return result
end

return _M 