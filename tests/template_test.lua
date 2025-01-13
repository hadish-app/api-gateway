--- Test suite template
-- @module tests.template_test
-- @description Template for standardized test structure

-- 1. Requires
local test_utils = require "tests.core.test_utils"

-- 2. Local helper functions
local function setup_test_environment()
    -- Reset state
    test_utils.reset_state()
    -- Add any other setup needed
end

-- 3. Module definition
local _M = {}

-- 4. Test setup (optional)
function _M.before_all()
    -- Run once before all tests
end

function _M.before_each()
    -- Run before each test
    setup_test_environment()
end

-- 5. Test cases
_M.tests = {
    {
        name = "Test: Description of test case",
        func = function()
            -- Test implementation
        end
    }
}

-- 6. Test cleanup (optional)
function _M.after_each()
    -- Run after each test
end

function _M.after_all()
    -- Run once after all tests
end

return _M 