local helpers = require "tests.core.test_helpers"

-- Example module we might be testing
local function create_example_module()
    local _M = {}
    
    function _M.process_request(method, uri, headers)
        if not method or not uri then
            return { status = 400, message = "Missing required parameters" }
        end
        
        if method ~= "GET" and method ~= "POST" then
            return { status = 405, message = "Method not allowed" }
        end
        
        if not headers["authorization"] then
            return { status = 401, message = "Unauthorized" }
        end
        
        return { 
            status = 200, 
            message = "Success",
            data = { method = method, uri = uri }
        }
    end
    
    return _M
end

describe("Example Module", function()
    local ngx
    local example_module
    
    setup(function()
        -- Run once before all tests
        example_module = create_example_module()
    end)
    
    before_each(function()
        -- Run before each test
        ngx = helpers.ngx
        helpers.reset_ngx()
    end)
    
    describe("process_request()", function()
        it("should return 400 when missing parameters", function()
            local result = example_module.process_request(nil, nil, {})
            assert.equals(400, result.status)
            assert.equals("Missing required parameters", result.message)
        end)
        
        it("should return 405 for invalid HTTP method", function()
            local result = example_module.process_request("PUT", "/test", {})
            assert.equals(405, result.status)
            assert.equals("Method not allowed", result.message)
        end)
        
        it("should return 401 when missing authorization", function()
            local result = example_module.process_request("GET", "/test", {})
            assert.equals(401, result.status)
            assert.equals("Unauthorized", result.message)
        end)
        
        it("should process valid GET request successfully", function()
            local headers = { authorization = "Bearer token" }
            local result = example_module.process_request("GET", "/test", headers)
            
            assert.equals(200, result.status)
            assert.equals("Success", result.message)
            assert.equals("GET", result.data.method)
            assert.equals("/test", result.data.uri)
        end)
        
        it("should handle request with query parameters", function()
            -- Mock a request with query parameters
            helpers.mock_request(
                "GET",
                "/test",
                { authorization = "Bearer token" },
                nil,
                { param1 = "value1" }
            )
            
            local result = example_module.process_request(
                ngx.var.request_method,
                ngx.var.uri,
                ngx.req.get_headers()
            )
            
            assert.equals(200, result.status)
            assert.equals("/test", result.data.uri)
        end)
    end)
    
    describe("Integration with ngx", function()
        it("should work with shared dictionaries", function()
            local dict = helpers.mock_shared_dict("my_cache")
            dict:set("key1", "value1")
            
            assert.equals("value1", dict:get("key1"))
            dict:delete("key1")
            assert.is_nil(dict:get("key1"))
        end)
        
        it("should handle request headers properly", function()
            local headers = { 
                ["content-type"] = "application/json",
                authorization = "Bearer token123"
            }
            
            -- Log headers before request
            ngx.log.info("Test starting - Headers to be set: " .. require("cjson").encode(headers))
            
            helpers.mock_request(
                "POST",
                "/api/data",
                headers,
                '{"key": "value"}'
            )
            
            -- Get and log actual headers
            local actual_headers = ngx.req.get_headers()
            ngx.log.info("Actual headers after mock: " .. require("cjson").encode(actual_headers))
            
            assert.equals("application/json", actual_headers["content-type"])
            assert.equals("Bearer token123", actual_headers["authorization"])
            
            -- Log test completion
            ngx.log.info("Test completed successfully")
        end)
    end)
end) 