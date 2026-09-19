--!strict
--!optimize 2
const Logging = require(script.Parent.Logging)
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)

local logger = Logging.getLogger("PeanutUI.Utils.Scheduler")

type Elements = {
    [string]: {() -> ()},
    defer: {() -> ()},
    refs: {() -> ()},
    createObject: {() -> ()},
    signals: {() -> ()},
    redraw: {() -> ()},
    settled: {() -> ()},

    -- Ran when scheduler stops
    idle: {() -> ()}
}

local scheduled: Elements = {
    createObject = {},
    signals = {},
    refs = {},
    redraw = {},
    defer = {},
    idle = {},
    settled = {}
}

local function execute(name: TypeFuncs.KeyOf<Elements>)
    local snapshot = scheduled[name]
    scheduled[name] = {}

    logger.debug("Running stage %s, snapshot size %d", name, #snapshot)
    for _, fn in snapshot do
        fn()
    end
end

local function drain(name: TypeFuncs.KeyOf<Elements>)
    local budget = 15
    while budget > 0 and #scheduled[name] > 0 do
        budget -= 1
        local snapshot = scheduled[name]
        scheduled[name] = {}

        logger.debug("Draining stage %s, snapshot size %d, budget left %d", name, #snapshot, budget)
        for _, fn in snapshot do
            fn()
        end
    end
end

local function step()
    execute("defer")
    drain("refs")
    execute("createObject")
    execute("signals")
    execute("redraw")
    execute("settled")
end

local ticksRanBeforeStop = 0
local isRunning = true
local isScheduled = false
local function scheduleNextStep()
    if not isRunning then return end
    if isScheduled then return end
    isScheduled = true

    task.defer(function()
        isScheduled = false

        if ticksRanBeforeStop >= 70 then
            logger.warn("Scheduler stopped after 70 consecutive ticks without becoming idle; a callback may be continuously scheduling more work")
            ticksRanBeforeStop = 0
            return
        end
        step()

        if not isScheduled then
            execute("idle")
        end

        if isScheduled then
            ticksRanBeforeStop += 1
        else
            logger.debug("Ticks ran before stop: %s", ticksRanBeforeStop)
            ticksRanBeforeStop = 0
        end
    end)
end

local function schedule<A...>(name: TypeFuncs.KeyOf<Elements>, fn: (A...) -> (), ...: A...): thread
    local co = coroutine.create(fn)

    local args = table.pack(... :: any)
    local function execute()
        task.spawn(co, table.unpack(args, 1, args.n))
    end

    table.insert(scheduled[name], execute)

    scheduleNextStep()
    return co
end

local function defer<A...>(fn: (A...) -> (), ...: A...): thread
    return schedule("defer", fn, ...)
end

local function idle<A...>(fn: (A...) -> (), ...: A...): thread
    return schedule("idle", fn, ...)
end

return {
    idle = idle,
    defer = defer,
    step = step,
    schedule = schedule
}
