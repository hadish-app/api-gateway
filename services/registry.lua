-- Service registry
return {
    health = {
        module = "services.health",
        routes = {
            {
                path = "/health",
                method = "GET",
                handler = "check"
            },
            {
                path = "/health/details",
                method = "GET",
                handler = "check_detailed"
            }
        }
    }
    -- Add more services here
} 