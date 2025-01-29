local cjson = require "cjson"
local ngx = ngx

local _M = {}

function _M.deep_clone(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = type(v) == "table" and _M.deep_clone(v) or v
    end
    return copy
end

function _M.array_to_string(arr)
    if not arr or #arr == 0 then return nil end
    return table.concat(arr, ", ")
end

function _M.prepare_headers_map(headers)
    local map = {}
    for _, header in ipairs(headers) do
        map[header:lower()] = true
    end
    return map
end

function _M.sanitize_header(value)
    if not value then return nil end
    return value:match("^[%w%p%s]+$") and value:gsub("[\r\n]+", "") or nil
end

function _M.format_cors_error(message, details)
    local parts = {
        "CORS Error",
        "Message: " .. message,
        "Origin: " .. (ngx.var.http_origin or "none"),
        "Method: " .. ngx.req.get_method(),
        "URI: " .. ngx.var.request_uri,
        "Client IP: " .. ngx.var.remote_addr
    }
    if details then
        table.insert(parts, "Details: " .. cjson.encode(details))
    end
    return table.concat(parts, ", ")
end

function _M.table_length(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function _M.split_csv(str)
    local result = {}
    if not str then return result end
    for value in str:gmatch("[^,]+") do
        result[#result + 1] = value:match("^%s*(.-)%s*$") -- trim whitespace
    end
    return result
end

-- Format array for display
local function format_array(arr)
    if not arr then return "nil" end
    if #arr == 0 then return "[]" end
    return "[" .. table.concat(arr, ", ") .. "]"
end

-- Compare two configs and return a human-readable diff
function _M.diff_configs( old_config, new_config)
    local changes = {}
    
    -- Helper function to compare arrays
    local function compare_arrays(new_arr, old_arr, field)
        if not new_arr or not old_arr then
            if new_arr ~= old_arr then
                table.insert(changes, string.format("%s changed:\n  - old: %s\n  - new: %s", 
                    field,
                    format_array(old_arr),
                    format_array(new_arr)
                ))
            end
            return
        end
        
        -- Check if arrays are different
        local is_different = false
        if #new_arr ~= #old_arr then
            is_different = true
        else
            local new_set, old_set = {}, {}
            for _, v in ipairs(new_arr) do new_set[v] = true end
            for _, v in ipairs(old_arr) do
                if not new_set[v] then
                    is_different = true
                    break
                end
            end
        end
        
        if is_different then
            -- Calculate additions and removals
            local new_set, old_set = {}, {}
            for _, v in ipairs(new_arr) do new_set[v] = true end
            for _, v in ipairs(old_arr) do old_set[v] = true end
            
            local added, removed = {}, {}
            for v in pairs(new_set) do
                if not old_set[v] then table.insert(added, v) end
            end
            for v in pairs(old_set) do
                if not new_set[v] then table.insert(removed, v) end
            end
            
            local diff_parts = {
                string.format("%s changed:", field),
                string.format("  - old: %s", format_array(old_arr)),
                string.format("  - new: %s", format_array(new_arr))
            }
            
            if #added > 0 then
                table.insert(diff_parts, string.format("  + added: %s", format_array(added)))
            end
            if #removed > 0 then
                table.insert(diff_parts, string.format("  - removed: %s", format_array(removed)))
            end
            
            table.insert(changes, table.concat(diff_parts, "\n"))
        end
    end
    
    -- Compare each field
    compare_arrays(new_config.allow_protocols, old_config.allow_protocols, "allow_protocols")
    compare_arrays(new_config.allow_origins, old_config.allow_origins, "allow_origins")
    compare_arrays(new_config.allow_methods, old_config.allow_methods, "allow_methods")
    compare_arrays(new_config.allow_headers, old_config.allow_headers, "allow_headers")
    compare_arrays(new_config.expose_headers, old_config.expose_headers, "expose_headers")
    
    -- Compare scalar values
    if new_config.max_age ~= old_config.max_age then
        table.insert(changes, string.format("max_age changed:\n  - old: %s\n  - new: %s", 
            tostring(old_config.max_age), 
            tostring(new_config.max_age)))
    end
    
    if new_config.allow_credentials ~= old_config.allow_credentials then
        table.insert(changes, string.format("allow_credentials changed:\n  - old: %s\n  - new: %s", 
            tostring(old_config.allow_credentials), 
            tostring(new_config.allow_credentials)))
    end
    
    if #changes == 0 then
        return "no changes"
    end
    
    return "\n" .. table.concat(changes, "\n\n")
end

-- Helper function to convert comma-separated headers to map
function _M.headers_to_map(headers_str)
    local result = {}
    if not headers_str then return result end
    for header in headers_str:gmatch("[^,]+") do
        result[header:match("^%s*(.-)%s*$"):lower()] = true
    end
    return result
end

return _M 