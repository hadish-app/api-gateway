-- Configuration Management Module
local _M = {}

-- Local references
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

-- Import environment utilities
local env = require "utils.env"

-- Convert value to appropriate type
local function convert_value(str)
    if str == "true" then return true
    elseif str == "false" then return false
    elseif tonumber(str) then return tonumber(str)
    else return str end
end

-- Initialize configuration
function _M.init()
    -- Get shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        return nil, "config_cache shared dictionary not found"
    end

    -- Load configuration from environment variables
    local config = env.load_all()
    
    -- Store configuration in shared dictionary
    for section, values in pairs(config) do
        if type(values) == "table" then
            local ok, err = config_cache:set(section, ngx.encode_args(values))
            if not ok then
                log(ERR, "Failed to store configuration section '", section, "': ", err)
                return nil, err
            end
            log(INFO, string.format("Stored configuration section: %s", section))
        end
    end

    log(INFO, "Configuration initialized successfully")
    return true
end

-- Get configuration value
function _M.get(section, key)
    -- Get shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        return nil, "config_cache shared dictionary not found"
    end

    local section_data = config_cache:get(section)
    if not section_data then
        return nil, "section not found: " .. section
    end

    local values = ngx.decode_args(section_data)
    if not values[key] then
        return nil, "key not found: " .. key
    end
    
    return convert_value(values[key])
end

-- Get entire configuration section
function _M.get_section(section)
    -- Get shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        return nil, "config_cache shared dictionary not found"
    end

    local section_data = config_cache:get(section)
    if not section_data then
        return nil, "section not found: " .. section
    end

    local values = ngx.decode_args(section_data)
    local result = {}
    for k, v in pairs(values) do
        result[k] = convert_value(v)
    end
    return result
end

-- Update configuration value
function _M.set(section, key, value)
    -- Get shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        return nil, "config_cache shared dictionary not found"
    end

    local section_data = config_cache:get(section)
    if not section_data then
        return nil, "section not found: " .. section
    end

    local values = ngx.decode_args(section_data)
    values[key] = tostring(value)
    
    local ok, err = config_cache:set(section, ngx.encode_args(values))
    if not ok then
        return nil, "failed to update configuration: " .. err
    end
    
    log(INFO, string.format("Updated configuration %s.%s = %s", section, key, tostring(value)))
    return true
end

return _M