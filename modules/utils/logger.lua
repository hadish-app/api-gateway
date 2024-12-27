local _M = {}

-- Log levels mapping
_M.LEVELS = {
    STDERR = ngx.STDERR,
    EMERG = ngx.EMERG,
    ALERT = ngx.ALERT,
    CRIT = ngx.CRIT,
    ERR = ngx.ERR,
    WARN = ngx.WARN,
    NOTICE = ngx.NOTICE,
    INFO = ngx.INFO,
    DEBUG = ngx.DEBUG
}

-- Format log message with request ID
local function format_log_message(message)
    local request_id = "-"
    local ok, err = pcall(function()
        request_id = ngx.ctx.request_id or "-"
    end)
    return string.format("[%s] %s", request_id, message)
end

-- Generic logging function
local function log(level, ...)
    local args = {...}
    local message = table.concat(args, " ")
    ngx.log(level, format_log_message(message))
end

-- Create logging functions for each level
function _M.debug(...)
    log(ngx.DEBUG, ...)
end

function _M.info(...)
    log(ngx.INFO, ...)
end

function _M.notice(...)
    log(ngx.NOTICE, ...)
end

function _M.warn(...)
    log(ngx.WARN, ...)
end

function _M.error(...)
    log(ngx.ERR, ...)
end

function _M.crit(...)
    log(ngx.CRIT, ...)
end

function _M.alert(...)
    log(ngx.ALERT, ...)
end

function _M.emerg(...)
    log(ngx.EMERG, ...)
end

return _M 