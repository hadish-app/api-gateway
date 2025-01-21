local lfs = require "lfs"
local test_utils = require "tests.core.test_utils"

local _M = {}

function _M.find_test_files(path, results)
    results = results or {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local full_path = path .. "/" .. file
            local attr = lfs.attributes(full_path)
            if attr.mode == "directory" then
                _M.find_test_files(full_path, results)
            elseif file:match("%.lua$") then
                -- Convert file path to module path
                local module_path = full_path:match("tests/modules/(.+)%.lua$")
                if module_path then
                    table.insert(results, module_path)
                end
            end
        end
    end
    return results
end

function _M.run_all_tests(base_path)
    local test_files = _M.find_test_files(base_path)
    local failed_tests = {}
    
    for _, test_path in ipairs(test_files) do
        ngx.log(ngx.INFO, "Running test module: ", test_path)
        
        local ok, test_module = pcall(require, "tests.modules." .. test_path)
        if ok and test_module.tests then
            test_utils.run_suite(test_path, test_module.tests, test_module.before_all, test_module.before_each, test_module.after_each, test_module.after_all)
        else
            ngx.log(ngx.ERR, "Failed to load test module: ", test_path)
            table.insert(failed_tests, test_path)
        end
    end
    
    return failed_tests
end

return _M 