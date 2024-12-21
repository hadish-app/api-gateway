local _M = {}

local security_headers = {
    ["X-Frame-Options"] = "DENY",
    ["X-Content-Type-Options"] = "nosniff",
    ["X-XSS-Protection"] = "1; mode=block",
    ["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains",
    ["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';",
    ["Referrer-Policy"] = "strict-origin-when-cross-origin",
    ["Feature-Policy"] = "camera 'none'; microphone 'none'; geolocation 'none'",
    ["X-Permitted-Cross-Domain-Policies"] = "none",
    ["X-Download-Options"] = "noopen"
}

function _M.execute(ctx)
    for header, value in pairs(security_headers) do
        ngx.header[header] = value
    end
    return true
end

return _M 