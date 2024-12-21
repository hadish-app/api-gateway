local _M = {}

function _M.execute(ctx)
    -- Set standard proxy headers
    ngx.req.set_header("Upgrade", ngx.var.http_upgrade)
    ngx.req.set_header("Connection", "upgrade")
    ngx.req.set_header("Host", ngx.var.host)
    ngx.req.set_header("X-Real-IP", ngx.var.remote_addr)
    ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    ngx.req.set_header("X-Forwarded-Proto", ngx.var.scheme)
    
    -- Set request ID from context
    if ctx.request_id then
        ngx.req.set_header("X-Request-ID", ctx.request_id)
    end
    
    -- Set timeouts from environment variables
    ngx.var.proxy_connect_timeout = os.getenv("PROXY_CONNECT_TIMEOUT") or "60"
    ngx.var.proxy_send_timeout = os.getenv("PROXY_SEND_TIMEOUT") or "60"
    ngx.var.proxy_read_timeout = os.getenv("PROXY_READ_TIMEOUT") or "60"
    
    return true
end

return _M 