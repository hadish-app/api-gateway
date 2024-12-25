-- Configuration Management Module
local _M = {}

-- Local references
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN

-- Import dependencies
local cjson = require "cjson"

-- Import utilities
local env = require "utils.env"
local type_conversion = require "utils.type_conversion"

-- Initialize configuration
-- This function loads configuration from environment variables and stores it in a shared dictionary
-- for efficient access across worker processes. The configuration is stored as key-value pairs
-- organized into sections. Each section's values are encoded as query parameters for storage.
-- @return boolean success, string? error_message, table? config_data
function _M.init()
    -- Get shared dictionary
    local config_cache = ngx.shared.config_cache
    if not config_cache then
        log(ERR, "Failed to initialize configuration: config_cache shared dictionary not found")
        return nil, "config_cache shared dictionary not found"
    end

    -- Load configuration from environment variables
    local env_config_sections, err = env.load_all()
    if not env_config_sections then
        log(ERR, "Failed to load environment configuration: ", err)
        return nil, "failed to load environment configuration: " .. (err or "unknown error")
    end

    if type(env_config_sections) ~= "table" then
        log(ERR, "Invalid environment configuration: expected table, got ", type(env_config_sections))
        return nil, "invalid environment configuration type"
    end

    -- Track configuration sections for validation
    local stored_sections = {}
    local config_data = {}

    -- Store configuration in shared dictionary
    for section, values in pairs(env_config_sections) do
        if type(values) ~= "table" then
            log(WARN, "Skipping invalid configuration section '", section, "': expected table, got ", type(values))
            goto continue
        end

        -- Encode and store section values
        local encoded_values = ngx.encode_args(values)
        local ok, err = config_cache:set(section, encoded_values)
        if not ok then
            log(ERR, "Failed to store configuration section '", section, "': ", err)
            return nil, "failed to store configuration section '" .. section .. "': " .. (err or "unknown error")
        end

        -- Track successful storage
        stored_sections[section] = true
        config_data[section] = values
        log(INFO, "Stored configuration section: ", section)

        ::continue::
    end

    -- Validate at least one section was stored
    if not next(stored_sections) then
        log(ERR, "No valid configuration sections found")
        return nil, "no valid configuration sections found"
    end

    -- Log full configuration for debugging
    log(INFO, "Configuration initialized successfully: ", cjson.encode(config_data))
    return true, nil, config_data
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
    
    return type_conversion.convert_value(values[key])
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
        result[k] = type_conversion.convert_value(v)
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