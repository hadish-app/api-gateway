local cjson = require "cjson"

local _M = {}

-- Get basic system metrics
local function get_basic_metrics()
    return {
        memory = {
            lua_used = collectgarbage("count") * 1024  -- Lua memory in bytes
        },
        connections = {
            active = ngx.var.connections_active,
            writing = ngx.var.connections_writing
        }
    }
end

-- Get detailed system metrics
local function get_detailed_metrics()
    -- Get memory info using lua-resty-core
    local memory_stats = {
        lua_used = collectgarbage("count") * 1024,  -- Lua memory in bytes
        worker_pid = ngx.worker.pid()
    }
    
    -- Get nginx connection stats
    local connections = {
        active = ngx.var.connections_active,
        reading = ngx.var.connections_reading,
        writing = ngx.var.connections_writing,
        waiting = ngx.var.connections_waiting
    }

    -- Get shared dictionaries info dynamically
    local shared_dicts = {}
    for dict_name, dict in pairs(ngx.shared) do
        shared_dicts[dict_name] = {
            free_space = dict:free_space(),
            capacity = dict:capacity(),
            keys = dict:get_keys(0)  -- 0 means get all keys
        }
    end
    
    return {
        memory = memory_stats,
        connections = connections,
        shared_dicts = shared_dicts,
        hostname = ngx.var.hostname,
        worker = {
            id = ngx.worker.id(),
            count = ngx.worker.count(),
            pid = memory_stats.worker_pid
        }
    }
end

-- Get basic performance metrics
local function get_basic_performance()
    return {
        request_time = ngx.now() - ngx.req.start_time()
    }
end

-- Get detailed performance metrics
local function get_detailed_performance()
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
end

-- Generate basic health check data
function _M.get_basic_health()
    local system = get_basic_metrics()
    local performance = get_basic_performance()
    
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
    local system = get_detailed_metrics()
    local performance = get_detailed_performance()
    
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
    local health_data, err = _M.get_detailed_health()
    if not health_data then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say(cjson.encode({ status = "error", error = err or "Failed to get detailed health data" }))
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(health_data))
    return ngx.exit(ngx.HTTP_OK)
end

return _M