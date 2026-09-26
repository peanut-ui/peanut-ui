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

local isRunning = false
local finallyHooks: {() -> ()} = {}
local passed = 0
local failed = 0

--- Run function with multiple tests
function Tests.runFunction(fn: () -> ())
    if isRunning then
        logger.error("Cannot run test inside of a test")
    end

    local originalLevel = Logging.getLevel()
    Logging.setLevel(4)

    xpcall(fn, function(err)
        logger.warn("Test function crashed with error:\n%s", tostring(err))
    end)

    logger.info("Tests passed: %d, tests failed: %d", passed, failed)
    Logging.setLevel(originalLevel)
end

--- Cleanup for test
function Tests.finally(fn: () -> ())
    if not isRunning then
        logger.error("No test is running")
    end
    table.insert(finallyHooks, fn)
end

--- Wrapper to safely run an isolated test block and catch unexpected crashes
function Tests.run(testName: string, fn: () -> ())
    if isRunning then
        logger.error("Cannot run test inside of a test")
    end
    isRunning = true

    logger.info("--- Running Test: %s ---", testName)

    local ok = xpcall(fn, function(err)
        logger.warn("Test %s: CRASHED with error:\n%s", testName, tostring(err))
    end)
    if ok then
        passed += 1
    else
        failed += 1
    end

    for _, fn in finallyHooks do
        xpcall(fn, function(msg)
            logger.warn("Cleanup function of test '%s' errored with message '%s', this may cause leaks", testName, tostring(msg))
        end)
    end
    table.clear(finallyHooks)

    logger.info("-----------------------------------------")
    isRunning = false
end

return Tests