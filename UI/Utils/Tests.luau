--!strict
--!optimize 2
-- Module for automated tests
const Logging = require(script.Parent.Logging)

const logger = Logging.getLogger("PeanutUI.Utils.Tests", 2)

const Tests = {}

-- Internal deep equality helper for tables and proxies
local function deepEqual(t1: any, t2: any): boolean
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    for k, v in pairs(t1) do
        if t2[k] == nil or not deepEqual(v, t2[k]) then return false end
    end
    for k, _ in pairs(t2) do
        if t1[k] == nil then return false end
    end
    return true
end

--- Asserts that a value matches the expected value
function Tests.expectValue(testName: string, value: any, expected: any)
    if value == expected then
        logger.info("Test %s: PASSED", testName)
    else
        logger.error("Test %s: FAILED; got %s, expected %s", testName, tostring(value), tostring(expected))
    end
end

--- Asserts that two tables or reactive proxies are deeply equal
function Tests.expectDeepEqual(testName: string, value: any, expected: any)
    if deepEqual(value, expected) then
        logger.info("Test %s: PASSED", testName)
    else
        logger.error("Test %s: FAILED; tables are not deep equal", testName)
    end
end

--- Asserts that a condition evaluates to true
function Tests.expectTrue(testName: string, condition: boolean)
    if condition == true then
        logger.info("Test %s: PASSED", testName)
    else
        logger.error("Test %s: FAILED; expected true, got false/nil", testName)
    end
end

--- Asserts that a condition evaluates to false
function Tests.expectFalse(testName: string, condition: boolean)
    if condition == false then
        logger.info("Test %s: PASSED", testName)
    else
        logger.error("Test %s: FAILED; expected false, got true", testName)
    end
end

--- Asserts that executing a function throws an error (Great for testing circular dependencies or type mismatches)
function Tests.expectError(testName: string, fn: () -> ())
    const ok, _ = pcall(fn)
    if not ok then
        logger.info("Test %s: PASSED (Correctly threw an error)", testName)
    else
        logger.error("Test %s: FAILED; expected an error to be thrown, but none occurred", testName)
    end
end

--- Wrapper to safely run an isolated test block and catch unexpected crashes
function Tests.run(testName: string, fn: () -> ())
    logger.info("--- Running Test: %s ---", testName)
    const ok, err = pcall(fn)
    if not ok then
        logger.warn("Test %s: CRASHED with error: %s", testName, tostring(err))
    end
    logger.info("-----------------------------------------")
end

return Tests