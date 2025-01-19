local _M = {}

-- Local references
local ngx = ngx
local shared = ngx.shared
local timer_every = ngx.timer.every


-- Import modules
local middleware_chain = require("modules.core.middleware_chain")
local middleware_registry = require("modules.core.middleware_registry")
local service_registry = require("modules.core.service_registry")
local env = require "modules.utils.env"
local cjson = require "cjson"

-- Constants and Configuration
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

-- Helper Functions
local function log_worker_state(worker_id, message)
    ngx.log(ngx.DEBUG, string.format("Worker %d %s - PID: %d, Memory: %.2fKB", 
        worker_id, 
        message,
        ngx.worker.pid(),
        collectgarbage("count")
    ))
end

local function log_shared_dict_state(stats, state_type)
    ngx.log(ngx.DEBUG, string.format("Shared dict 'stats' %s state - Free: %d, Capacity: %d, Keys: %d",
        state_type,
        stats:free_space(),
        stats:capacity(),
        #stats:get_keys(0)
    ))
end

-- Core Initialization Functions
local function verify_shared_dicts()
    ngx.log(ngx.DEBUG, "Starting shared dictionary verification...")
    
    -- List all available shared dictionaries
    local available_dicts = {}
    for dict_name, _ in pairs(shared) do
        available_dicts[dict_name] = true
        ngx.log(ngx.DEBUG, "Found shared dictionary: " .. dict_name)
    end
    
    for _, dict_name in ipairs(SHARED_DICTS.required) do
        if not shared[dict_name] then
            ngx.log(ngx.ERR, "Required shared dictionary not found: " .. dict_name)
            return false
        end
        ngx.log(ngx.DEBUG, "Verified shared dictionary: " .. dict_name)
    end
    return true
end

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
        ngx.log(ngx.ERR, "Failed to initialize shared states: " .. err)
        return nil, err
    end

    return true
end

local function init_config_cache()
    ngx.log(ngx.DEBUG, "Initializing configuration cache...")
    
    -- Load all environment variables
    local config = env.load_all()
    
    -- Store in shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        ngx.log(ngx.ERR, "Failed to access config_cache shared dictionary")
        return nil
    end
    
    -- Serialize and store each section
    for section, values in pairs(config) do
        local json_str, err = cjson.encode(values)
        if err then
            ngx.log(ngx.ERR, "Failed to encode config section: ", section, ", error: ", err)
            return nil
        end
        local ok, err = config_cache:set(section, json_str)
        if not ok then
            ngx.log(ngx.ERR, "Failed to cache config section: ", section, ", error: ", err)
            return nil
        end
        ngx.log(ngx.DEBUG, "Cached config section: ", section)
    end
    
    ngx.log(ngx.DEBUG, "Configuration cache initialized successfully")
    return true
end

-- Phase Handler Functions
function _M.init()
    ngx.log(ngx.DEBUG, "Starting initialization phase...")
    
    local ok, err
    
    -- Sequential initialization steps
    if not verify_shared_dicts() then
        return nil, "Failed to verify shared dictionaries"
    end

    ok, err = init_shared_states()
    if not ok then
        return nil, "Failed to initialize shared states: " .. err
    end
    
    ok, err = init_config_cache()
    if not ok then
        ngx.log(ngx.ERR, "Failed to initialize configuration cache")
        return false
    end
    
    -- Register components
    ok, err = middleware_registry.register()
    if not ok then
        ngx.log(ngx.ERR, "Failed to register middlewares: ", err)
        return false
    end
    
    ok, err = service_registry.register()
    if not ok then
        ngx.log(ngx.ERR, "Failed to register services: ", err)
        return false
    end
    
    ngx.log(ngx.DEBUG, "Initialization phase completed successfully")
    return true
end

function _M.init_worker()
    ngx.log(ngx.DEBUG, "Starting worker initialization phase...")
    
    local worker_id = ngx.worker.id()
    local worker_pid = ngx.worker.pid()
    local stats = shared.stats
    
    if not stats then
        ngx.log(ngx.ERR, "Stats dictionary not available during worker initialization")
        return nil, "Stats dictionary not available"
    end
    
    -- Log initial states
    log_worker_state(worker_id, "initial state")
    log_shared_dict_state(stats, "initial")
    
    -- Store worker start time
    local worker_key = "worker:" .. worker_id .. ":start_time"
    local start_time = ngx.now()
    
    local success, err = stats:safe_set(worker_key, start_time, 3600)
    if not success then
        if err == "exists" then
            local existing = stats:get(worker_key)
            ngx.log(ngx.DEBUG, string.format("Worker %d start time already set to %.6f", worker_id, existing))
        else
            ngx.log(ngx.ERR, "Failed to store worker start time: " .. (err or "unknown error"))
            return nil, "Failed to store worker start time"
        end
    else
        ngx.log(ngx.DEBUG, string.format("Stored start time for worker %d (PID: %d): %.6f", 
            worker_id, worker_pid, start_time))
    end
    
    -- Verify and log final states
    local stored = stats:get(worker_key)
    if stored then
        ngx.log(ngx.DEBUG, string.format("Verified worker %d start time: %.6f", worker_id, stored))
        log_worker_state(worker_id, "final state")
        log_shared_dict_state(stats, "final")
    else
        ngx.log(ngx.ERR, string.format("Failed to verify worker %d start time", worker_id))
    end

    ngx.log(ngx.DEBUG, "Worker initialization completed successfully")
    return true
end

-- Standard phase handlers
local function create_phase_handler(phase_name)
    return function()
        ngx.log(ngx.DEBUG, string.format("%s phase handler started", phase_name))
        local result = middleware_chain.run_chain(phase_name)
        ngx.log(ngx.DEBUG, string.format("%s phase handler completed", phase_name))
        return result
    end
end

_M.access = create_phase_handler("access")
_M.content = create_phase_handler("content")
_M.header_filter = create_phase_handler("header_filter")
_M.body_filter = create_phase_handler("body_filter")
_M.log = create_phase_handler("log")

return _M 