local _M = {}

-- Function to get ISO8601 timestamp with milliseconds
function _M.get_iso8601_timestamp()
    local now = ngx.now()
    local ms = string.format("%03d", math.floor((now - math.floor(now)) * 1000))
    return os.date("!%Y-%m-%dT%H:%M:%S.", math.floor(now)) .. ms .. "+00:00"
end

return _M 