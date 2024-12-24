-- test_helpers.lua
local _M = {}

-- Store captured logs by type
_M.logs = {
    access = {},  -- For access logs (brief, detailed, json formats)
    error = {},   -- For error level logs
    debug = {},   -- For debug level logs
    info = {}     -- For info level logs
}

-- Log formats matching production
local function format_access_log_json(req)
    return string.format([[{
        "timestamp":"%s",
        "client":"%s",
        "request":"%s",
        "status":%d,
        "bytes_sent":%d,
        "request_time":%f
    }]], 
    os.date("!%Y-%m-%dT%H:%M:%S%z"),
    req.client or "test-client",
    req.request or "TEST",
    req.status or 200,
    req.bytes_sent or 0,
    req.request_time or 0
    )
end

local function format_access_log_brief(req)
    return string.format("[%s] %s %s -> %d (%f sec)",
        os.date("!%Y-%m-%dT%H:%M:%S%z"),
        req.method or "TEST",
        req.uri or "/",
        req.status or 200,
        req.request_time or 0
    )
end

-- Helper to get logs by level
function _M.get_logs_by_level(level)
    local filtered = {}
    if level == "access" then
        for _, log in ipairs(_M.logs.access) do
            table.insert(filtered, log)
        end
    else
        for _, log in ipairs(_M.logs[level] or {}) do
            table.insert(filtered, log.message)
        end
    end
    return filtered
end

-- Mock the ngx variable with more production-like behavior
_M.ngx = {
    var = {
        request_method = "GET",
        remote_addr = "test-client",
        request_uri = "/test",
        time_iso8601 = function() return os.date("!%Y-%m-%dT%H:%M:%S%z") end,
        request_time = 0,
        body_bytes_sent = 0
    },
    ctx = {},
    header = {},
    req = {
        get_headers = function() return {} end,
        get_uri_args = function() return {} end,
        read_body = function() end,
        get_body_data = function() return "" end,
        get_method = function() return "GET" end
    },
    location = {
        capture = function() return { status = 200 } end
    },
    log = {
        info = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[INFO] " .. msg)  -- Print to stdout for immediate visibility
            table.insert(_M.logs.info, { level = "info", message = msg })
        end,
        error = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[ERROR] " .. msg)
            table.insert(_M.logs.error, { level = "error", message = msg })
        end,
        warn = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[WARN] " .. msg)
            table.insert(_M.logs.info, { level = "warn", message = msg })
        end,
        debug = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[DEBUG] " .. msg)
            table.insert(_M.logs.debug, { level = "debug", message = msg })
        end
    },
    say = function(...) end,
    exit = function(status) return status end,
    status = function(status) return status end,
    shared = {},  -- For shared dict operations
    time = function() return os.time() end,
    now = function() return os.time() end,
    re = {
        match = function(...) return ... end,
        find = function(...) return ... end,
        sub = function(...) return ... end
    }
}

-- Helper to reset ngx mock between tests
function _M.reset_ngx()
    _M.ngx.var = {
        request_method = "GET",
        remote_addr = "test-client",
        request_uri = "/test",
        time_iso8601 = function() return os.date("!%Y-%m-%dT%H:%M:%S%z") end,
        request_time = 0,
        body_bytes_sent = 0
    }
    _M.ngx.ctx = {}
    _M.ngx.header = {}
    _M.ngx.shared = {}
    -- Reset all log types
    _M.logs = {
        access = {},
        error = {},
        debug = {},
        info = {}
    }
end

-- Enhanced mock request helper with access logging
function _M.mock_request(method, uri, headers, body, args)
    local start_time = os.time()
    
    -- Set request details
    _M.ngx.var.request_method = method
    _M.ngx.var.uri = uri
    _M.ngx.req.get_headers = function() return headers or {} end
    _M.ngx.req.get_uri_args = function() return args or {} end
    _M.ngx.req.get_body_data = function() return body or "" end
    
    -- Log access in different formats
    local req = {
        method = method,
        uri = uri,
        status = 200,
        request_time = os.time() - start_time,
        bytes_sent = #(body or ""),
        client = "test-client"
    }
    
    table.insert(_M.logs.access, format_access_log_json(req))
    table.insert(_M.logs.access, format_access_log_brief(req))
end

return _M 