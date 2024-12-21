local _M = {}

local function collect_metrics(ctx)
    local metrics = {
        method = ngx.req.get_method(),
        uri = ngx.var.uri,
        status = ngx.status,
        request_time = ngx.now() - ctx.start_time,
        remote_addr = ngx.var.remote_addr,
        bytes_sent = tonumber(ngx.var.bytes_sent) or 0,
        request_length = tonumber(ngx.var.request_length) or 0,
        http_user_agent = ngx.var.http_user_agent,
        timestamp = ngx.now()
    }
    
    -- Add the metrics to shared dictionary for prometheus to collect
    local shared_dict = ngx.shared.metrics
    if shared_dict then
        local key = string.format("%s_%s_%s", metrics.method, metrics.uri, metrics.status)
        local success, err = shared_dict:incr(key, 1, 0)
        if not success then
            ngx.log(ngx.ERR, "failed to increment metrics: ", err)
        end
        
        -- Store request time for calculating averages
        local rt_key = key .. "_rt"
        local rt_count_key = key .. "_rt_count"
        shared_dict:incr(rt_count_key, 1, 0)
        shared_dict:incr(rt_key, metrics.request_time, 0)
    end
    
    return metrics
end

function _M.execute(ctx)
    -- Collect metrics at the end of request processing
    ngx.ctx.metrics = collect_metrics(ctx)
    return true
end

return _M 