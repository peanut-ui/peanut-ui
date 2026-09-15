--!strict
--!optimize 2
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)

type Elements = {
    [string]: {() -> ()},
    refs: {() -> ()},
    createObject: {() -> ()},
    signals: {() -> ()},
    redraw: {() -> ()},
    defer: {() -> ()}
}

local function makeNew(): Elements
    return {
        createObject = {},
        signals = {},
        events = {},
        refs = {},
        redraw = {},
        defer = {},
    }
end

local scheduled = makeNew()

local function execute(from: Elements, name: TypeFuncs.KeyOf<Elements>)
    for _, fn in from[name] do
        fn()
    end
end

local function step()
    local executes = scheduled
    scheduled = makeNew()

    execute(executes, "refs")
    execute(executes, "createObject")
    execute(executes, "signals")
    execute(executes, "redraw")
    execute(executes, "defer")
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
        step()

        if isScheduled then
            ticksRanBeforeStop += 1
        else
            print("Tick ran before stop", ticksRanBeforeStop)
            ticksRanBeforeStop = 0
        end
    end)
end

local function schedule<A...>(name: TypeFuncs.KeyOf<Elements>, fn: (A...) -> (), ...: A...): thread
    local co = coroutine.create(fn)

    local args = table.pack(... :: any)
    local function execute()
        task.spawn(co, table.unpack(args))
    end

    table.insert(scheduled[name], execute)

    scheduleNextStep()
    return co
end

local function defer<A...>(fn: (A...) -> (), ...: A...): thread
    local co = coroutine.create(fn)

    local args = table.pack(... :: any)
    local function execute()
        task.spawn(co, table.unpack(args))
    end

    table.insert(scheduled.defer, execute)

    scheduleNextStep()
    return co
end

return {
    defer = defer,
    step = step,
    schedule = schedule
}
