--!strict
--!optimize 2
const Helpers = require(script.Parent.Helpers)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)

local logger = Logging.getLogger("PeanutUI.Utils.ComponentContext")

export type NoContext = false

local stack: {Utils.Bucket | NoContext} = {}
local Module = {}

local disableYielding = Helpers.disableYielding

local counter = 0
local function createBucket<State>(name: string?, customState: State?): Utils.Bucket<State>
    local stopped = false
    local cleanups = {}

    return {
        cleanups = cleanups,
        customState = customState,
        contextName = name or "unknown",

        addCleanup = function(callback: () -> ()): number
            if stopped then
                logger.error("Tried to access Bucket after it was stopped")
            end
            counter += 1
            local id = counter
            cleanups[id] = callback
            return id
        end,

        removeCleanup = function(id: number)
            if stopped then return end
            cleanups[id] = nil
        end,

        stop = function()
            if stopped then return end
            stopped = true
            local toCleanup = cleanups
            cleanups = nil :: any

            for i = #toCleanup, -1, 1 do
                local fn = toCleanup[i]
                fn()
            end
        end
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
Module.createBucket = createBucket

function Module.push(name: string?)
    table.insert(stack, createBucket(name))
end

function Module.pushBucket(bucket: Utils.Bucket)
    table.insert(stack, bucket)
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

function Module.withContext<R, A...>(name: string?, fn: (A...) -> R, ...: A...): (boolean, R, Utils.Bucket?)
    Module.push(name)

    local ok, result = disableYielding(fn, ...)
    if not ok then
        logger.warn(`Call resulted in error:\n{result}`)
    end

    return ok, result :: R, Module.pop()
end

function Module.withContextBucket<R, A...>(bucket: Utils.Bucket, fn: (A...) -> R, ...: A...): (boolean, R)
    Module.pushBucket(bucket)

    local ok, result = disableYielding(fn, ...)
    if not ok then
        logger.warn(`Call resulted in error:\n{result}`)
    end

    Module.pop()
    return ok, result :: R
end

function Module.withNoContext<R, A...>(fn: (A...) -> R, ...: A...): (boolean, R)
    Module.pushNoContext()

    local ok, result = disableYielding(fn, ...)
    if not ok then
        logger.warn(`Call resulted in error:\n{result}`)
    end

    Module.pop()
    return ok, result :: R
end

return table.freeze(Module)