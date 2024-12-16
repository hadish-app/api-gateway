local _M = {}

-- Function to get environment variable with type conversion
function _M.get_env(name, default_value, value_type)
    local value = os.getenv(name)
    if not value then
        return default_value
    end
    
    if value_type == "number" then
        value = tonumber(value)
        if not value then
            ngx.log(ngx.WARN, string.format("Invalid number format for %s, using default: %s", name, default_value))
            return default_value
        end
    elseif value_type == "boolean" then
        value = value:lower()
        if value == "true" or value == "1" then
            return true
        elseif value == "false" or value == "0" then
            return false
        else
            ngx.log(ngx.WARN, string.format("Invalid boolean format for %s, using default: %s", name, default_value))
            return default_value
        end
    end
    
    return value
end

return _M 