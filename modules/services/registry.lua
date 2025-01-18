-- Service registry
return {
    health = {
        module = "modules.services.health",
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