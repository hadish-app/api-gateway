-- Standardized error handling
local M = {}

local error_handlers = {
    ["default"] = function(err)
        return { status = 500, message = "Internal Server Error" }
    end,
    ["validation"] = function(err)
        return { status = 400, message = err }
    end,
    ["auth"] = function(err)
        return { status = 401, message = err }
    end
}

function M.handle(err_type, err)
    local handler = error_handlers[err_type] or error_handlers["default"]
    return handler(err)
end

return M
