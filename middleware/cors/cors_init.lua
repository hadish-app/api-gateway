local cjson = require "cjson"
local config = require "middleware.cors.cors_config"

local _M = {}

-- Initialize CORS module
function _M.init()
    ngx.log(ngx.INFO, "[cors] Starting CORS initialization...")
    config.configure();
    ngx.log(ngx.INFO, "[cors] CORS initialization completed")
    return true
end

return _M

