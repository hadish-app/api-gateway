local test_utils = require "tests.core.test_utils"
local type_conversion = require "modules.utils.type_conversion"

local _M = {}

_M.tests = {
    {
        name = "Test convert_value with boolean strings",
        func = function()
            test_utils.assert_equals(true, type_conversion.convert_value("true"), "Should convert 'true' to boolean true")
            test_utils.assert_equals(false, type_conversion.convert_value("false"), "Should convert 'false' to boolean false")
        end
    },
    {
        name = "Test convert_value with numeric strings",
        func = function()
            test_utils.assert_equals(123, type_conversion.convert_value("123"), "Should convert numeric string to number")
            test_utils.assert_equals(-45.67, type_conversion.convert_value("-45.67"), "Should convert negative float string to number")
        end
    },
    {
        name = "Test convert_value with regular strings",
        func = function()
            test_utils.assert_equals("hello", type_conversion.convert_value("hello"), "Should keep regular strings unchanged")
            test_utils.assert_equals("123abc", type_conversion.convert_value("123abc"), "Should keep invalid number strings unchanged")
        end
    },
    {
        name = "Test convert_value with non-string input",
        func = function()
            test_utils.assert_equals(123, type_conversion.convert_value(123), "Should return numbers unchanged")
            test_utils.assert_equals(true, type_conversion.convert_value(true), "Should return booleans unchanged")
            test_utils.assert_equals(nil, type_conversion.convert_value(nil), "Should return nil unchanged")
        end
    },
    {
        name = "Test to_boolean with valid inputs",
        func = function()
            test_utils.assert_equals(true, type_conversion.to_boolean("true"), "Should convert 'true' to true")
            test_utils.assert_equals(true, type_conversion.to_boolean("YES"), "Should convert 'YES' to true")
            test_utils.assert_equals(true, type_conversion.to_boolean("1"), "Should convert '1' to true")
            test_utils.assert_equals(true, type_conversion.to_boolean("on"), "Should convert 'on' to true")
            test_utils.assert_equals(false, type_conversion.to_boolean("false"), "Should convert 'false' to false")
            test_utils.assert_equals(false, type_conversion.to_boolean("NO"), "Should convert 'NO' to false")
            test_utils.assert_equals(false, type_conversion.to_boolean("0"), "Should convert '0' to false")
            test_utils.assert_equals(false, type_conversion.to_boolean("off"), "Should convert 'off' to false")
        end
    },
    {
        name = "Test to_boolean with invalid inputs",
        func = function()
            test_utils.assert_equals(nil, type_conversion.to_boolean("invalid"), "Should return nil for invalid boolean string")
            test_utils.assert_equals(nil, type_conversion.to_boolean(123), "Should return nil for non-string input")
            test_utils.assert_equals(nil, type_conversion.to_boolean(nil), "Should return nil for nil input")
        end
    },
    {
        name = "Test to_number with valid inputs",
        func = function()
            test_utils.assert_equals(123, type_conversion.to_number("123"), "Should convert integer string to number")
            test_utils.assert_equals(-45.67, type_conversion.to_number("-45.67"), "Should convert float string to number")
            test_utils.assert_equals(0, type_conversion.to_number("0"), "Should convert zero string to number")
        end
    },
    {
        name = "Test to_number with invalid inputs",
        func = function()
            test_utils.assert_equals(nil, type_conversion.to_number("abc"), "Should return nil for invalid number string")
            test_utils.assert_equals(nil, type_conversion.to_number(""), "Should return nil for empty string")
            test_utils.assert_equals(nil, type_conversion.to_number(nil), "Should return nil for nil input")
        end
    }
}

return _M 