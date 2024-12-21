local _M = {}

local allowed_origins = {}
local allowed_methods = "GET, POST, PUT, DELETE, PATCH, OPTIONS"
local allowed_headers = "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
local max_age = "1728000"  -- 20 days

-- Initialize allowed origins from environment variable
local function init_origins()
    local origins = os.getenv("ALLOWED_ORIGINS")
    if origins then
        for origin in string.gmatch(origins, "([^,]+)") do
            allowed_origins[origin:match("^%s*(.-)%s*$")] = true
        end
    end
end

-- Check if origin is allowed
local function is_origin_allowed(origin)
    if not origin then return false end
    if next(allowed_origins) == nil then return true end  -- If no origins specified, allow all
    return allowed_origins[origin] == true
end

function _M.execute(ctx)
    if not next(allowed_origins) then
        init_origins()
    end

    local origin = ngx.req.get_headers()["Origin"]
    if not origin then return true end

    if is_origin_allowed(origin) then
        ngx.header["Access-Control-Allow-Origin"] = origin
        ngx.header["Access-Control-Allow-Methods"] = allowed_methods
        ngx.header["Access-Control-Allow-Headers"] = allowed_headers
        ngx.header["Access-Control-Max-Age"] = max_age
        ngx.header["Access-Control-Allow-Credentials"] = "true"
    end

    if ngx.req.get_method() == "OPTIONS" then
        return ngx.exit(ngx.HTTP_NO_CONTENT)
    end

    return true
end

return _M 