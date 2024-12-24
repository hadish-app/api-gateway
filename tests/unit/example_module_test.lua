local helpers = require "tests.core.test_helpers"

-- Example module we might be testing
local function create_example_module()
    local _M = {}
    
    function _M.process_request(method, uri, headers)
        -- Log incoming request details for debugging
        ngx.log.info("Processing request:", {
            method = method,
            uri = uri,
            headers = headers
        })

        -- Basic validation
        if not method or not uri then
            return { status = 400, message = "Missing required parameters" }
        end

        -- Process request and return response
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
            -- Test input validation
            local result = example_module.process_request(nil, nil, {})
            assert.equals(400, result.status)
            assert.equals("Missing required parameters", result.message)
        end)
        
        it("should process valid request successfully", function()
            -- Prepare test data
            local headers = { ["x-test"] = "test-value" }
            
            -- Log test execution
            ngx.log.info("Testing with headers: " .. require("cjson").encode(headers))
            
            -- Execute test
            local result = example_module.process_request("GET", "/test", headers)
            
            -- Verify results
            assert.equals(200, result.status)
            assert.equals("Success", result.message)
            assert.equals("GET", result.data.method)
            assert.equals("/test", result.data.uri)
            
            -- Log test completion
            ngx.log.info("Test completed with result: " .. require("cjson").encode(result))
        end)
    end)
end) 