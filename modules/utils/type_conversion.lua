local _M = {}

-- Convert string value to its appropriate Lua type
-- @param str (string) The string value to convert
-- @return (any) The converted value (boolean, number, or string)
function _M.convert_value(str)
    if type(str) ~= "string" then
        return str  -- Return as-is if not a string
    end

    -- Convert to appropriate type
    if str == "true" then 
        return true
    elseif str == "false" then 
        return false
    elseif tonumber(str) then 
        return tonumber(str)
    else 
        return str 
    end
end

-- Convert string value to boolean
-- @param str (string) The string value to convert
-- @return (boolean|nil) The boolean value or nil if invalid
function _M.to_boolean(str)
    if type(str) ~= "string" then
        return nil
    end
    
    str = string.lower(str)
    if str == "true" or str == "1" or str == "yes" or str == "on" then
        return true
    elseif str == "false" or str == "0" or str == "no" or str == "off" then
        return false
    end
    return nil
end

-- Convert string value to number
-- @param str (string) The string value to convert
-- @return (number|nil) The number value or nil if invalid
function _M.to_number(str)
    return tonumber(str)
end

return _M 