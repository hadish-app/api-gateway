-- Integration test for environment variable utilities
local test_utils = require "tests.core.test_utils"
local env = require "utils.env"

local _M = {}

-- Helper function to test section configuration
local function test_section(config, section_name, expected_values)
    test_utils.assert_equals("table", type(config[section_name]), section_name .. " section exists")
    if config[section_name] then
        for key, expected in pairs(expected_values) do
            test_utils.assert_equals(expected, config[section_name][key], 
                string.format("%s.%s value matches", section_name, key))
        end
    end
end

-- Helper function to parse section and key from environment variable name
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

-- Helper function to get environment variables
local function get_env_vars()
    local env_values = {}
    
    -- Get environment variables from process
    local handle = io.popen('env')
    if not handle then
        ngx.log(ngx.ERR, "Failed to get environment variables")
        return env_values
    end
    
    for line in handle:lines() do
        local name, value = line:match('([^=]+)=(.*)')
        if name and value then
            -- Convert boolean strings
            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            -- Convert numbers
            elseif tonumber(value) then
                value = tonumber(value)
            end
            
            -- Parse section and key
            local section, key = parse_env_name(name)
            if section and key then
                -- Initialize section if needed
                env_values[section] = env_values[section] or {}
                -- Store value
                env_values[section][key] = value
            end
        end
    end
    handle:close()
    return env_values
end

-- Define test cases
_M.tests = {
    {
        name = "Test: Environment loading",
        func = function()
            local config = env.load_all()
            test_utils.assert_equals("table", type(config), "Configuration loaded successfully")
            if type(config) == "table" then
                ngx.say("Loaded configuration:")
                ngx.say(require("cjson").encode(config))
            end
        end
    },
    {
        name = "Test: Verify environment variables match loaded configuration",
        func = function()
            -- Get environment variables
            local env_values = get_env_vars()
            -- Check if we have any values
            test_utils.assert_equals(true, next(env_values) ~= nil, "Environment variables loaded successfully")
            
            -- Load configuration
            local config = env.load_all()
            test_utils.assert_equals("table", type(config), "Configuration loaded successfully")
            
            -- Test each section dynamically
            for section, values in pairs(env_values) do
                test_section(config, section, values)
            end
        end
    }
}

return _M 