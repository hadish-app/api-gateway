-- Middleware registry
return {
    request_id = {
        module = "modules.middleware.request_id",
        enabled = true,
        multi_phase = true,
        phases = {
            access = { priority = 10 },
            header_filter = { priority = 10 },
            log = { priority = 10 }
        }
    },

    cors = {
        module = "modules.middleware.cors.init",
        enabled = true,
        multi_phase = true,
        phases = {
            access = { priority = 20 },
            header_filter = { priority = 20 },
            log = { priority = 20 }
        }
    },

    router = {
        module = "modules.middleware.router",
        enabled = true,
        multi_phase = false,
        phase = "content",
        priority = 100  -- Run after other content phase middleware
    }
}