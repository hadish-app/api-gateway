local M = {}

function M.init()
    local config = require "config"
    config.init()
    
    -- Store start time for uptime calculation
    ngx.shared.stats:set("start_time", ngx.time())
end

return M 