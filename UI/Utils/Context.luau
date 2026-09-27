--!strict
--!optimize 2
const Helpers = require(script.Parent.Helpers)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)

local logger = Logging.getLogger("PeanutUI.Utils.ComponentContext")

export type NoContext = false

local currentBucket: Utils.Bucket | NoContext? = nil
local stack: {Utils.Bucket | NoContext} = {}
local Module = {}

local disableYielding = Helpers.disableYielding
local freezeAndClear = Helpers.freezeAndClear

type CleanupNode = {
    id: number,
    callback: () -> (),
    previous: CleanupNode?,
    next: CleanupNode?,
}

local counter = 0
local function createBucket<State>(name: string?, customState: State?): Utils.Bucket<State>
    local stopped = false
    local cleanups: {[number]: () -> ()} = {}
    local nodes: {[number]: CleanupNode} = {}
    local tail: CleanupNode? = nil

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
            local node: CleanupNode = {
                id = id,
                callback = callback,
                previous = tail,
                next = nil,
            }

            if tail then
                tail.next = node
            end

            tail = node
            cleanups[id] = callback
            nodes[id] = node
            return id
        end,

        removeCleanup = function(id: number)
            if stopped then return end

            local node = nodes[id]
            if not node then return end

            if node.previous then
                node.previous.next = node.next
            end

            if node.next then
                node.next.previous = node.previous
            else
                tail = node.previous
            end

            cleanups[id] = nil
            nodes[id] = nil
        end,

        stop = function()
            if stopped then return end
            stopped = true

            local node = tail
            freezeAndClear(cleanups)
            freezeAndClear(nodes)
            tail = nil

            while node do
                local previous = node.previous
                node.callback()
                node = previous
            end
        end,
    }
end

local function getCurrentBucket(): Utils.Bucket?
    if currentBucket == false then
        return nil
    end

    return currentBucket
end

Module.getCurrentBucket = getCurrentBucket
Module.createBucket = createBucket

function Module.push(name: string?)
    local bucket = createBucket(name)
    table.insert(stack, bucket)
    currentBucket = bucket
end

function Module.pushBucket(bucket: Utils.Bucket)
    table.insert(stack, bucket)
    currentBucket = bucket
end

function Module.pushNoContext()
    table.insert(stack, false :: NoContext)
    currentBucket = false
end

function Module.pop(): Utils.Bucket?
    local last = table.remove(stack)
    currentBucket = stack[#stack]

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