local helpers = require "tests.core.test_helpers"
local cjson = require "cjson"

-- Example module we might be testing
local function create_example_module(ngx)
    local _M = {}
    
    function _M.process_request(method, uri, headers)
        -- Log incoming request details for debugging
        if ngx and ngx.log then
            ngx.log.debug("Received request parameters")
            ngx.log.info("Processing request: ", cjson.encode({
                method = method,
                uri = uri,
                headers = headers
            }))
        end

        -- Basic validation
        if not method or not uri then
            if ngx and ngx.log then
                ngx.log.error("Invalid request: missing method or URI")
            end
            return { status = 400, message = "Missing required parameters" }
        end

        -- Process request and return response
        if ngx and ngx.log then
            ngx.log.info("Request processed successfully")
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
        ngx = helpers.ngx
        example_module = create_example_module(ngx)
    end)
    
    before_each(function()
        -- Run before each test
        helpers.reset_ngx()
    end)
    
    describe("process_request()", function()
        it("should return 400 and log error when missing parameters", function()
            -- Mock the request
            helpers.mock_request(nil, nil, {})
            
            -- Test input validation
            local result = example_module.process_request(nil, nil, {})
            
            -- Check response
            assert.equals(400, result.status)
            assert.equals("Missing required parameters", result.message)
            
            -- Verify error was logged
            local error_logs = helpers.get_logs_by_level("error")
            assert.equals(1, #error_logs)
            assert.matches("Invalid request", error_logs[1])
            
            -- Verify access logs were created
            local access_logs = helpers.get_logs_by_level("access")
            assert.equals(2, #access_logs)  -- One JSON, one brief format
            assert.matches("test%-client", access_logs[1])  -- JSON format
            assert.matches("%[%d%d%d%d%-%d%d%-%d%d", access_logs[2])  -- Brief format
        end)
        
        it("should process valid request successfully and log all levels", function()
            -- Prepare test data
            local headers = { ["x-test"] = "test-value" }
            
            -- Mock the request
            helpers.mock_request("GET", "/test", headers)
            
            -- Execute test
            local result = example_module.process_request("GET", "/test", headers)
            
            -- Verify results
            assert.equals(200, result.status)
            assert.equals("Success", result.message)
            assert.equals("GET", result.data.method)
            assert.equals("/test", result.data.uri)
            
            -- Verify debug logs
            local debug_logs = helpers.get_logs_by_level("debug")
            assert.equals(1, #debug_logs)
            assert.matches("Received request parameters", debug_logs[1])
            
            -- Verify info logs
            local info_logs = helpers.get_logs_by_level("info")
            assert.equals(2, #info_logs)
            assert.matches("Processing request", info_logs[1])
            assert.matches("Request processed successfully", info_logs[2])
            
            -- Verify access logs
            local access_logs = helpers.get_logs_by_level("access")
            assert.equals(2, #access_logs)
            assert.matches("GET /test", access_logs[2])  -- Brief format
        end)
    end)
end) 