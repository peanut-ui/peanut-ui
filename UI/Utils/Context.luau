--!strict
--!optimize 2
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)

local logger = Logging.getLogger("PeanutUI.Utils.ComponentContext")

export type NoContext = false

local stack: {Utils.Bucket | NoContext} = {}
local Module = {}

local function disableYielding<R, A...>(fn: (A...) -> R, ...: A...): (boolean, R?)
    local thread = coroutine.create(fn)

    local ok, result = coroutine.resume(thread, ...)

    if not ok then
        local errorTrace = debug.traceback(thread, tostring(result))
        return false, errorTrace
    end

    if coroutine.status(thread) ~= "dead" then
        local trace = debug.traceback(thread)
        coroutine.close(thread)

        return false, `Cannot yield in current context.\nHINT: check for tags: yield in method's description\nTraceback: {trace}`
    end

    return true, result
end

local function createBucket(): Utils.Bucket
    return {
        createdRefs = {},
        onCreatedHooks = {},
        onSetupHooks = {},
        onBeforeDestroyedHooks = {},
        onDestroyedHooks = {}
    }
end

local function getCurrentBucket(): Utils.Bucket?
    if #stack == 0 then
        return nil
    end

    local current = stack[#stack]
    if current == false then
        return nil
    end

    return current
end

Module.getCurrentBucket = getCurrentBucket

function Module.push()
    table.insert(stack, createBucket())
end

function Module.pushNoContext()
    table.insert(stack, false :: NoContext)
end

function Module.pop(): Utils.Bucket?
    local last = table.remove(stack)

    if last == false then
        return nil
    end

    return last
end

function Module.withContext<R, A...>(fn: (A...) -> R, ...: A...): (boolean, R, Utils.Bucket?)
    Module.push()

    local ok, result = disableYielding(fn, ...)
    if not ok then
        logger.warn(`Call resulted in error:\n{result}`)
    end

    return ok, result, Module.pop()
end

function Module.withNoContext<R, A...>(fn: (A...) -> R, ...: A...): (boolean, R)
    Module.pushNoContext()

    local ok, result = disableYielding(fn, ...)
    if not ok then
        logger.warn(`Call resulted in error:\n{result}`)
    end

    Module.pop()
    return ok, result
end

return Module