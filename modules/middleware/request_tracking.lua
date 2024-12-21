local uuid = require "resty.jit-uuid"
local _M = {}

local function generate_request_id()
    return string.format("%s-%s",
        os.getenv("API_GATEWAY_NAME") or "api",
        uuid.generate_v4()
    )
end

local function log_request()
    local req_headers = ngx.req.get_headers()
    local log_entry = {
        timestamp = ngx.now(),
        request_id = ngx.ctx.request_id,
        method = ngx.req.get_method(),
        uri = ngx.var.uri,
        query_string = ngx.var.query_string,
        remote_addr = ngx.var.remote_addr,
        user_agent = req_headers["user-agent"],
        referer = req_headers["referer"],
        forwarded_for = req_headers["x-forwarded-for"],
        real_ip = ngx.var.remote_addr
    }
    
    ngx.log(ngx.INFO, require("cjson").encode(log_entry))
end

function _M.execute(ctx)
    -- Generate and set request ID
    local request_id = ngx.req.get_headers()["x-request-id"] or generate_request_id()
    ngx.ctx.request_id = request_id
    ngx.header["x-request-id"] = request_id
    
    -- Log the request
    log_request()
    
    return true
end

return _M 