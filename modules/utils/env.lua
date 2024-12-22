-- Environment variable utilities
local _M = {}

-- Local references
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

-- Get environment variable value
local function get_env_value(name)
    -- Try ngx.env first if available
    if ngx and ngx.env then
        return ngx.env[name]
    end
    -- Fallback to os.getenv
    return os.getenv(name)
end

-- List all environment variables
local function list_env_vars()
    local env_vars = {}
    
    -- Get environment variables from process
    local handle = io.popen('env')
    if handle then
        for line in handle:lines() do
            local name, value = line:match('([^=]+)=(.*)')
            if name then
                env_vars[name] = value
            end
        end
        handle:close()
    end
    
    return env_vars
end

-- Infer type and convert value
local function infer_and_convert(value)
    if not value then
        return nil
    end
    
    -- Try number conversion first
    local num = tonumber(value)
    if num then
        return num
    end
    
    -- Check for boolean values
    local lower = value:lower()
    if lower == "true" or lower == "1" or lower == "yes" then
        return true
    elseif lower == "false" or lower == "0" or lower == "no" then
        return false
    end
    
    -- Handle special string cases
    if value == "" then
        return nil
    end
    
    -- Default to string
    return value
end

-- Parse section and key from environment variable name
local function parse_env_name(name)
    -- Convert from uppercase with underscores to lowercase with dots
    local lower = name:lower()
    
    -- Split by underscore
    local parts = {}
    for part in lower:gmatch("[^_]+") do
        parts[#parts + 1] = part
    end
    
    -- Need at least 2 parts for section.key
    if #parts < 2 then
        return nil, nil
    end
    
    -- First part is the section
    local section = parts[1]
    
    -- Rest becomes the key
    table.remove(parts, 1)
    local key = table.concat(parts, "_")
    
    return section, key
end

-- Load all environment variables
function _M.load_all()
    local config = {}
    
    -- Get all environment variables
    local env_vars = list_env_vars()
    
    -- Process each environment variable
    for name, value in pairs(env_vars) do
        local section, key = parse_env_name(name)
        
        -- Only process variables that follow our naming convention
        if section and key then
            -- Convert the value
            local converted = infer_and_convert(value)
            if converted ~= nil then
                -- Initialize section if needed
                config[section] = config[section] or {}
                -- Store value with flattened key
                config[section][key] = converted
                
                log(INFO, string.format("Loaded env var %s as %s.%s = %s", 
                    name, section, key, tostring(converted)))
            end
        end
    end
    
    return config
end

return _M