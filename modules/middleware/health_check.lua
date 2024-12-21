local _M = {}

-- Initialize stats in init_worker
function _M.init_worker()
    local stats = ngx.shared.stats
    if not stats:get("total_requests") then
        stats:set("total_requests", 0)
        stats:set("total_errors", 0)
        stats:set("2xx", 0)
        stats:set("3xx", 0)
        stats:set("4xx", 0)
        stats:set("5xx", 0)
    end
end

-- Update request stats
function _M.update_stats()
    local stats = ngx.shared.stats
    stats:incr("total_requests", 1, 0)
    
    -- Track status code
    local status = ngx.status
    local status_group = math.floor(status / 100) .. "xx"
    stats:incr(status_group, 1, 0)
    
    -- Track errors (4xx and 5xx)
    if status >= 400 then
        stats:incr("total_errors", 1, 0)
    end
end

-- Get memory usage stats
local function get_memory_stats()
    local file = io.open("/proc/self/status", "r")
    if not file then return {} end
    
    local stats = {}
    for line in file:lines() do
        local name, value = line:match("^([^:]+):%s+(%d+)")
        if name and (name == "VmRSS" or name == "VmSize") then
            stats[name] = tonumber(value)
        end
    end
    file:close()
    return stats
end

-- Get connection stats
local function get_connection_stats()
    return {
        active = tonumber(ngx.var.connections_active) or 0,
        reading = tonumber(ngx.var.connections_reading) or 0,
        writing = tonumber(ngx.var.connections_writing) or 0,
        waiting = tonumber(ngx.var.connections_waiting) or 0
    }
end

-- Get request statistics
local function get_request_stats()
    local stats_dict = ngx.shared.stats
    local total_requests = stats_dict:get("total_requests") or 0
    local total_errors = stats_dict:get("total_errors") or 0
    
    -- Calculate requests per second
    local current_time = ngx.now()
    local last_time = stats_dict:get("last_time") or current_time
    local last_count = stats_dict:get("last_count") or total_requests
    local time_diff = current_time - last_time
    
    -- Avoid division by zero and ensure valid numbers
    local rps = 0
    if time_diff > 0 then
        rps = (total_requests - last_count) / time_diff
        -- Ensure it's a valid number
        if rps ~= rps or rps == math.huge or rps == -math.huge then
            rps = 0
        end
    end
    
    -- Update stats for next calculation
    stats_dict:set("last_time", current_time)
    stats_dict:set("last_count", total_requests)
    
    -- Ensure error_rate is a valid number
    local error_rate = 0
    if total_requests > 0 then
        error_rate = total_errors / total_requests
        if error_rate ~= error_rate or error_rate == math.huge or error_rate == -math.huge then
            error_rate = 0
        end
    end
    
    return {
        total_requests = total_requests,
        requests_per_second = math.floor(rps * 100) / 100,
        error_rate = error_rate,
        status_codes = {
            ["2xx"] = stats_dict:get("2xx") or 0,
            ["3xx"] = stats_dict:get("3xx") or 0,
            ["4xx"] = stats_dict:get("4xx") or 0,
            ["5xx"] = stats_dict:get("5xx") or 0
        }
    }
end

-- Get worker process stats
local function get_worker_stats()
    local workers = {}
    for i = 0, ngx.worker.count() - 1 do
        workers[i + 1] = {
            id = i,
            pid = ngx.worker.pid(),
            count = ngx.worker.count(),
            exiting = ngx.worker.exiting()
        }
    end
    return workers
end

-- Get shared dict usage
local function get_shared_dict_stats()
    local dicts = {
        "stats", "ip_blacklist", "rate_limit_store", "config"
    }
    local usage = {}
    for _, dict_name in ipairs(dicts) do
        local dict = ngx.shared[dict_name]
        if dict then
            local capacity = dict:capacity()
            local free_space = dict:free_space()
            usage[dict_name] = {
                capacity = capacity,
                used = capacity - free_space,
                free = free_space,
                usage_percent = math.floor((1 - free_space/capacity) * 100)
            }
        end
    end
    return usage
end

-- Get rate limit config
local function get_rate_limit_config()
    return {
        requests_per_second = tonumber(os.getenv("RATE_LIMIT_RPS")) or 10,
        burst = tonumber(os.getenv("RATE_LIMIT_BURST")) or 20
    }
end

-- Get active bans count
local function get_active_bans()
    local ban_dict = ngx.shared.ip_blacklist
    if not ban_dict then return 0 end
    
    local count = 0
    local keys = ban_dict:get_keys(0)
    for _, _ in ipairs(keys) do
        count = count + 1
    end
    return count
end

-- Get system load average (Linux only)
local function get_load_avg()
    local file = io.open("/proc/loadavg", "r")
    if not file then return nil end
    
    local content = file:read("*l")
    file:close()
    
    if not content then return nil end
    
    local load1, load5, load15 = content:match("^(%d+%.%d+)%s+(%d+%.%d+)%s+(%d+%.%d+)")
    return {
        last1min = tonumber(load1),
        last5min = tonumber(load5),
        last15min = tonumber(load15)
    }
end

function _M.execute(ctx)
    if ngx.var.uri == "/health" then
        local start_time = ngx.shared.stats:get("start_time") or ngx.now()
        
        local health_data = {
            status = "healthy",
            timestamp = ngx.now(),
            version = os.getenv("API_GATEWAY_VERSION") or "unknown",
            metrics = {
                memory = get_memory_stats(),
                connections = get_connection_stats(),
                requests = get_request_stats(),
                workers = get_worker_stats(),
                shared_dicts = get_shared_dict_stats(),
                config = get_rate_limit_config(),
                bans = get_active_bans(),
                uptime_seconds = ngx.now() - start_time,
                load = get_load_avg()
            }
        }
        
        ngx.header.content_type = "application/json"
        ngx.say(require("cjson").encode(health_data))
        return ngx.exit(ngx.HTTP_OK)
    end
    
    return true
end

return _M 