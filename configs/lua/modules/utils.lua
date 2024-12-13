local _M = {}

-- Function to get ISO8601 timestamp with milliseconds
function _M.get_iso8601_timestamp()
    local now = ngx.now()
    local ms = string.format("%03d", math.floor((now - math.floor(now)) * 1000))
    return os.date("!%Y-%m-%dT%H:%M:%S.", math.floor(now)) .. ms .. "+00:00"
end

-- Function to format duration for display
function _M.format_duration(seconds)
    if seconds < 60 then
        return string.format("%d seconds", seconds)
    else
        return string.format("%d minutes", math.ceil(seconds/60))
    end
end

return _M 