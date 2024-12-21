local _M = {}

local function parse_url(url)
    if not url then return nil end
    
    local m = ngx.re.match(url, [[^(?:http://)?([^:/]+)(?::(\d+))?]], "jo")
    if not m then return nil end
    
    return {
        host = m[1],
        port = tonumber(m[2]) or 80
    }
end

local function check_backend_health()
    local backends = {
        admin = os.getenv("ADMIN_SERVICE_URL"),
        auth = os.getenv("AUTH_SERVICE_URL"),
        api = os.getenv("API_SERVICE_URL")
    }
    
    local results = {}
    for name, url in pairs(backends) do
        if not url then
            results[name] = {
                status = "down",
                error = "service URL not configured"
            }
        else
            local parsed = parse_url(url)
            if not parsed then
                results[name] = {
                    status = "down",
                    error = "invalid service URL format"
                }
            else
                local sock = ngx.socket.tcp()
                sock:settimeout(1000)  -- 1 second timeout
                
                local ok, err = sock:connect(parsed.host, parsed.port)
                if not ok then
                    results[name] = {
                        status = "down",
                        error = err
                    }
                else
                    results[name] = {
                        status = "up"
                    }
                end
                sock:close()
            end
        end
    end
    
    return results
end

function _M.execute(ctx)
    if ngx.var.uri == "/health" then
        local health_data = {
            status = "ok",
            timestamp = ngx.now(),
            version = os.getenv("API_GATEWAY_VERSION") or "unknown",
            backends = check_backend_health()
        }
        
        ngx.header.content_type = "application/json"
        ngx.say(require("cjson").encode(health_data))
        return ngx.exit(ngx.HTTP_OK)
    end
    
    return true
end

return _M 