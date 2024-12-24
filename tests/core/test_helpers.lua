-- test_helpers.lua
local _M = {}

-- Store captured logs
_M.logs = {}

-- Mock the ngx variable with more production-like behavior
_M.ngx = {
    var = {},
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
            table.insert(_M.logs, { level = "info", message = msg })
        end,
        error = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[ERROR] " .. msg)
            table.insert(_M.logs, { level = "error", message = msg })
        end,
        warn = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[WARN] " .. msg)
            table.insert(_M.logs, { level = "warn", message = msg })
        end,
        debug = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            print("[DEBUG] " .. msg)
            table.insert(_M.logs, { level = "debug", message = msg })
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
    _M.ngx.var = {}
    _M.ngx.ctx = {}
    _M.ngx.header = {}
    _M.ngx.shared = {}
    _M.logs = {}  -- Clear logs between tests
end

-- Helper to mock HTTP responses
function _M.mock_http_response(status, body, headers)
    return {
        status = status or 200,
        body = body or "",
        headers = headers or {}
    }
end

-- Helper to simulate shared dictionary operations
function _M.mock_shared_dict(dict_name)
    local dict = {}
    _M.ngx.shared[dict_name] = {
        get = function(_, key) return dict[key] end,
        set = function(_, key, value) dict[key] = value; return true end,
        delete = function(_, key) dict[key] = nil; return true end,
        incr = function(_, key, value) 
            dict[key] = (dict[key] or 0) + value
            return dict[key]
        end
    }
    return _M.ngx.shared[dict_name]
end

-- Helper to mock request data
function _M.mock_request(method, uri, headers, body, args)
    _M.ngx.var.request_method = method
    _M.ngx.var.uri = uri
    _M.ngx.req.get_headers = function() return headers or {} end
    _M.ngx.req.get_uri_args = function() return args or {} end
    _M.ngx.req.get_body_data = function() return body or "" end
end

return _M 