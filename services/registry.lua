-- Service registry
return {
    health = {
        id = "health",
        module = "services.health",
        routes = {
            {
                id = "health_check",
                path = "/health",
                method = "GET",
                handler = "check",
                cors = {
                    id = "health_check",                    
                    allow_origins = { "http://wc.com" }
                    
                }
            },
            {
                id = "health_details",
                path = "/health/details",
                method = "GET",
                handler = "check_detailed",
                cors = {
                    id = "health_details",
                    allow_origins = { "https://example.com" }
                }
            }
        },
        cors = {            
            allow_protocols = { "http", "https" },
            allow_methods = { "GET" },
            allow_headers = { "Content-Type" },
            allow_credentials = false,
            max_age = 3600,
            expose_headers = { "X-Request-ID" }
        }
    }
    -- Add more services here
} 