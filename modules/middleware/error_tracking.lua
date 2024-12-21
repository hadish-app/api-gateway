local cjson = require "cjson"
local _M = {}

local function get_error_response(status, message, details)
    return {
        error = {
            status = status,
            message = message,
            details = details,
            timestamp = ngx.now(),
            request_id = ngx.ctx.request_id,
            path = ngx.var.uri
        }
    }
end

local function log_error(err_data)
    local log_entry = {
        timestamp = ngx.now(),
        error = err_data.error,
        request = {
            method = ngx.req.get_method(),
            uri = ngx.var.uri,
            headers = ngx.req.get_headers(),
            remote_addr = ngx.var.remote_addr,
            request_id = ngx.ctx.request_id
        }
    }
    
    ngx.log(ngx.ERR, cjson.encode(log_entry))
end

function _M.execute(ctx)
    if ctx.error then
        local status = ctx.error.status or ngx.HTTP_INTERNAL_SERVER_ERROR
        local message = ctx.error.message or "Internal Server Error"
        local details = ctx.error.details
        
        local err_response = get_error_response(status, message, details)
        log_error(err_response)
        
        ngx.status = status
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode(err_response))
        return ngx.exit(status)
    end
    
    return true
end

return _M 