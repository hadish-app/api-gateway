local cjson = require "cjson"
local ngx = ngx

local _M = {}

-- Helper function to get worker start time
local function get_worker_start_time(worker_id)
    local stats = ngx.shared.stats
    if not stats then
        return nil, "Stats dictionary not available"
    end
    
    local worker_key = "worker:" .. worker_id .. ":start_time"
    local start_time, err = stats:get(worker_key)
    if not start_time then
        return nil, "Failed to get worker start time: " .. (err or "not found")
    end
    
    return start_time
end

-- Helper function to get all worker start times
local function get_all_worker_start_times(worker_count)
    local stats = ngx.shared.stats
    if not stats then
        ngx.log(ngx.ERR, "Stats dictionary not available")
        return {}
    end
    
    local times = {}
    local now = ngx.now()
    local current_worker = ngx.worker.id()
    
    for i = 0, worker_count - 1 do
        local worker_key = "worker:" .. i .. ":start_time"
        local start_time = stats:get(worker_key)
        
        -- Only include workers that have registered their start time
        if start_time then
            local uptime = now - start_time
            times[i] = {
                start_time = start_time,
                uptime = uptime,
                status = "running",
                last_seen = now  -- Current time as last seen
            }
            ngx.log(ngx.DEBUG, string.format("Worker %d: start_time=%.6f, uptime=%.6f", 
                i, start_time, uptime))
        else
            times[i] = {
                start_time = nil,
                uptime = 0,
                status = "not_started_or_exited",
                last_seen = nil
            }
            ngx.log(ngx.DEBUG, string.format("Worker %d: not found or exited", i))
        end
        
        -- Add extra information for current worker
        if i == current_worker then
            times[i].is_current = true
            times[i].pid = ngx.worker.pid()
        end
    end
    return times
end

-- Get basic system metrics with error handling
local function get_basic_metrics()
    local ok, metrics = pcall(function()
        return {
            memory = {
                lua_used = collectgarbage("count") * 1024  -- Lua memory in bytes
            },
            connections = {
                active = ngx.var.connections_active or 0,
                writing = ngx.var.connections_writing or 0
            }
        }
    end)

    if not ok then
        return nil, "Failed to collect basic metrics: " .. (metrics or "unknown error")
    end
    return metrics
end

-- Get detailed system metrics with error handling
local function get_detailed_metrics()
    local memory_stats, conn_stats, shared_stats
    
    -- Get memory info with validation
    local ok, err = pcall(function()
        local lua_used = collectgarbage("count")
        if not lua_used or lua_used <= 0 then
            return nil, "Invalid memory usage value"
        end
        
        memory_stats = {
            lua_used = lua_used * 1024,
            worker_pid = ngx.worker.pid()
        }
    end)
    if not ok then
        return nil, "Failed to collect memory stats: " .. (err or "unknown error")
    end
    
    -- Validate connection stats
    ok, err = pcall(function()
        local active = tonumber(ngx.var.connections_active) or 0
        local reading = tonumber(ngx.var.connections_reading) or 0
        local writing = tonumber(ngx.var.connections_writing) or 0
        local waiting = tonumber(ngx.var.connections_waiting) or 0
        
        if active < (reading + writing) then
            return nil, "Invalid connection counts"
        end
        
        conn_stats = {
            active = active,
            reading = reading,
            writing = writing,
            waiting = waiting
        }
    end)
    if not ok then
        return nil, "Failed to collect connection stats: " .. (err or "unknown error")
    end
    
    -- Get worker information
    local worker_id = ngx.worker.id()
    local worker_count = ngx.worker.count()
    
    if not worker_id or not worker_count or worker_id >= worker_count then
        return nil, "Invalid worker configuration"
    end
    
    -- Get worker start time from shared dictionary
    local start_time, start_err = get_worker_start_time(worker_id)
    if not start_time then
        ngx.log(ngx.WARN, "Failed to get worker start time: ", start_err)
        start_time = 0  -- Fallback to 0 if start time is not available
    end
    
    -- Calculate uptime
    local worker_uptime = ngx.now() - start_time

    -- Enhanced shared dictionary validation
    ok, err = pcall(function()
        shared_stats = {}
        for dict_name, dict in pairs(ngx.shared) do
            if type(dict) ~= "table" then
                ngx.log(ngx.WARN, "Invalid shared dict type for: ", dict_name)
                goto continue
            end
            
            local dict_info, dict_err = pcall(function()
                local free_space = dict:free_space()
                local capacity = dict:capacity()
                
                if not free_space or not capacity or free_space > capacity then
                    return nil, "Invalid dictionary metrics"
                end
                
                return {
                    free_space = free_space,
                    capacity = capacity,
                    keys = dict:get_keys(0),
                    utilization = ((capacity - free_space) / capacity) * 100
                }
            end)
            
            if dict_info then
                shared_stats[dict_name] = dict_err -- In pcall success case, dict_err contains the data
            else
                ngx.log(ngx.WARN, "Failed to get stats for dict ", dict_name, ": ", dict_err)
                shared_stats[dict_name] = { error = "Failed to collect metrics" }
            end
            
            ::continue::
        end
    end)
    if not ok then
        return nil, "Failed to collect shared dictionary stats: " .. (err or "unknown error")
    end
    
    return {
        hostname = ngx.var.hostname,
        worker = {
            id = worker_id,
            count = worker_count,
            pid = memory_stats.worker_pid,
            uptime = worker_uptime
        },
        memory = {
            lua_used = memory_stats.lua_used,
            lua_used_mb = math.floor(memory_stats.lua_used / 1024 / 1024 * 100) / 100
        },
        connections = conn_stats,
        shared_dicts = shared_stats
    }
end

-- Get basic performance metrics with error handling
local function get_basic_performance()
    local ok, perf = pcall(function()
        return {
            request_time = ngx.now() - ngx.req.start_time()
        }
    end)
    
    if not ok then
        return nil, "Failed to collect basic performance metrics: " .. (perf or "unknown error")
    end
    return perf
end

-- Get detailed performance metrics with error handling
local function get_detailed_performance()
    local ok, perf = pcall(function()
        return {
            request_time = ngx.now() - ngx.req.start_time(),
            upstream_response_time = ngx.var.upstream_response_time,
            upstream_connect_time = ngx.var.upstream_connect_time,
            upstream_status = ngx.var.upstream_status,
            request = {
                remote_addr = ngx.var.remote_addr,
                request_method = ngx.var.request_method,
                request_uri = ngx.var.request_uri,
                server_protocol = ngx.var.server_protocol,
                scheme = ngx.var.scheme,
                host = ngx.var.host
            }
        }
    end)
    
    if not ok then
        return nil, "Failed to collect detailed performance metrics: " .. (perf or "unknown error")
    end
    return perf
end

-- Generate basic health check data
function _M.get_basic_health()
    local system, sys_err = get_basic_metrics()
    if not system then
        return nil, sys_err
    end
    
    local performance, perf_err = get_basic_performance()
    if not performance then
        return nil, perf_err
    end
    
    return {
        status = "healthy",
        timestamp = ngx.now() * 1000,
        version = "1.0.0",
        system = system,
        performance = performance
    }
end

-- Generate detailed health check data
function _M.get_detailed_health()
    local system, sys_err = get_detailed_metrics()
    if not system then
        return nil, sys_err
    end
    
    local performance, perf_err = get_detailed_performance()
    if not performance then
        return nil, perf_err
    end
    
    return {
        status = "healthy",
        timestamp = ngx.now() * 1000,
        version = "1.0.0",
        system = system,
        performance = performance
    }
end

-- Handle basic health check response
function _M.check()
    local health_data, err = _M.get_basic_health()
    if not health_data then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say(cjson.encode({ status = "error", error = err or "Failed to get health data" }))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(health_data))
    return ngx.exit(ngx.HTTP_OK)
end

-- Handle detailed health check response
function _M.check_detailed()
    local system, err = get_detailed_metrics()
    if not system then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({ 
            status = "error", 
            error = err or "Failed to get detailed health data",
            timestamp = ngx.now() * 1000
        }))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    
    -- Get worker information
    local worker_id = ngx.worker.id()
    local worker_count = ngx.worker.count()
    local worker_times = get_all_worker_start_times(worker_count)
    
    -- Format worker details
    local workers = {
        count = worker_count,
        current = {
            id = worker_id,
            pid = ngx.worker.pid(),
            uptime = worker_times[worker_id] and worker_times[worker_id].uptime or 0,
            start_time = worker_times[worker_id] and worker_times[worker_id].start_time or nil,
            status = worker_times[worker_id] and worker_times[worker_id].status or "unknown"
        },
        all = {}
    }
    
    -- Add all worker details
    for i = 0, worker_count - 1 do
        local worker_info = worker_times[i] or {}
        workers.all[i] = {
            id = i,
            pid = worker_info.pid,
            start_time = worker_info.start_time,
            uptime = worker_info.uptime or 0,
            status = worker_info.status or "unknown",
            is_current = worker_info.is_current or false,
            last_seen = worker_info.last_seen
        }
    end
    
    -- Format shared dictionary details
    local shared_dicts = {}
    for dict_name, dict in pairs(ngx.shared) do
        local capacity = dict:capacity()
        local free_space = dict:free_space()
        local used_space = capacity - free_space
        
        shared_dicts[dict_name] = {
            capacity = capacity,
            free_space = free_space,
            used_space = used_space,
            utilization = math.floor((used_space / capacity) * 10000) / 100,  -- 2 decimal places
            keys = dict:get_keys(0)
        }
    end
    
    local response = {
        status = "healthy",
        timestamp = ngx.now() * 1000,
        version = "1.0.0",
        system = {
            hostname = ngx.var.hostname,
            workers = workers,
            memory = {
                lua_used = collectgarbage("count") * 1024,
                lua_used_mb = math.floor(collectgarbage("count") / 1024 * 100) / 100
            },
            connections = {
                active = tonumber(ngx.var.connections_active) or 0,
                reading = tonumber(ngx.var.connections_reading) or 0,
                writing = tonumber(ngx.var.connections_writing) or 0,
                waiting = tonumber(ngx.var.connections_waiting) or 0
            },
            shared_dicts = shared_dicts
        },
        performance = {
            request = {
                remote_addr = ngx.var.remote_addr,
                request_method = ngx.var.request_method,
                request_uri = ngx.var.request_uri,
                host = ngx.var.host,
                protocol = ngx.var.server_protocol,
                scheme = ngx.var.scheme
            },
            request_time = ngx.now() - ngx.req.start_time()
        }
    }
    
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(response))
    return ngx.exit(ngx.HTTP_OK)
end

return _M