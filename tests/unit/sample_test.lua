local helpers = require "tests.core.test_helpers"

describe("Sample Test Suite", function()
    local ngx = helpers.ngx
    
    before_each(function()
        helpers.reset_ngx()
    end)

    it("should demonstrate a simple test", function()
        assert.is_true(true)
    end)

    it("should demonstrate ngx mock usage", function()
        ngx.var.request_method = "GET"
        assert.equals("GET", ngx.var.request_method)
    end)

    it("should demonstrate table assertions", function()
        local response = helpers.mock_http_response(200, "OK", {["Content-Type"] = "application/json"})
        assert.equals(200, response.status)
        assert.equals("OK", response.body)
        assert.equals("application/json", response.headers["Content-Type"])
    end)
end) 