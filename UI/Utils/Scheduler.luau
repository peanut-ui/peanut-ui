--!strict
--!optimize 2
const Logging = require(script.Parent.Logging)
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)

local logger = Logging.getLogger("PeanutUI.Utils.Scheduler")

type Elements = {
    [string]: {() -> ()},
    defer: {() -> ()},
    watchers: {() -> ()},
    create: {() -> ()},
    signals: {() -> ()},
    redraw: {() -> ()},
    settled: {() -> ()},

    -- Ran when scheduler stops
    idle: {() -> ()}
}

type StageAdditional = {
    stepRan: {[string]: boolean}
}

type Phases = {
    [string]: Elements & StageAdditional,
    before: Elements & StageAdditional,
    schedule: Elements & StageAdditional,
    after: Elements & StageAdditional
}

local scheduled: Phases = {
    before = {
        stepRan = {},
        create = {},
        signals = {},
        watchers = {},
        redraw = {},
        defer = {},
        idle = {},
        settled = {}
    },
    schedule = {
        stepRan = {},
        create = {},
        signals = {},
        watchers = {},
        redraw = {},
        defer = {},
        idle = {},
        settled = {}
    },
    after = {
        stepRan = {},
        create = {},
        signals = {},
        watchers = {},
        redraw = {},
        defer = {},
        idle = {},
        settled = {}
    }
}

local currentStage = "sync"
local currentStagePhase = "sync"
local isFlushing = false

local function executeStage(stage: TypeFuncs.KeyOf<Elements>, phase: TypeFuncs.KeyOf<Phases>)
    currentStage = stage
    currentStagePhase = phase

    local stageScheduled = scheduled[phase]

    local stepRan = stageScheduled.stepRan
    stepRan[stage] = true

    local snapshot = stageScheduled[stage]
    stageScheduled[stage] = {}

    logger.debug("Running stage %s, phase: %s, snapshot size %d", stage, phase, #snapshot)
    for _, fn in snapshot do
        fn()
    end
end

local function drainStage(stage: TypeFuncs.KeyOf<Elements>, phase: TypeFuncs.KeyOf<Phases>)
    currentStage = stage
    currentStagePhase = phase

    local stageScheduled = scheduled[phase]
    local stepRan = stageScheduled.stepRan

    local budget = 15
    while budget > 0 and #stageScheduled[stage] > 0 do
        budget -= 1
        local snapshot = stageScheduled[stage]
        stageScheduled[stage] = {}

        logger.debug("Draining stage %s, phase: %s, snapshot size %d, budget left %d", stage, phase, #snapshot, budget)
        for _, fn in snapshot do
            fn()
        end

        if budget <= 0 then
            stepRan[stage] = true
        end
    end

    stepRan[stage] = true
end

local function execute(stage: TypeFuncs.KeyOf<Elements>)
    executeStage(stage, "before")
    executeStage(stage, "schedule")
    executeStage(stage, "after")
end

local function drain(stage: TypeFuncs.KeyOf<Elements>)
    executeStage(stage, "before")
    drainStage(stage, "schedule")
    executeStage(stage, "after")
end

local function step()
    execute("defer")
    drain("watchers")
    execute("create")
    execute("signals")
    execute("redraw")
    execute("settled")

    scheduled.before.stepRan = {} :: any
    scheduled.schedule.stepRan = {} :: any
    scheduled.after.stepRan = {} :: any
    currentStage = "sync"
    currentStagePhase = "sync"
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
        isFlushing = true

        if ticksRanBeforeStop >= 70 then
            logger.warn("Scheduler stopped after 70 consecutive ticks without becoming idle; a callback may be continuously scheduling more work")
            ticksRanBeforeStop = 0
            isFlushing = false
            return
        end

        ticksRanBeforeStop += 1
        step()

        if not isScheduled then
            execute("idle")
        end

        if not isScheduled then
            logger.debug("Ticks ran before stop: %s", ticksRanBeforeStop)
            ticksRanBeforeStop = 0
        end

        isFlushing = false
    end)
end

local function scheduleAt<A...>(stage: TypeFuncs.KeyOf<Elements>, phase: TypeFuncs.KeyOf<Phases>, fn: (A...) -> (), ...: A...): thread
    local co = coroutine.create(fn)

    local args = table.pack(... :: any)
    local function execute()
        task.spawn(co, table.unpack(args, 1, args.n))
    end

    local stageScheduled = scheduled[phase]
    local stepRan = stageScheduled.stepRan

    table.insert(stageScheduled[stage], execute)

    if not isFlushing or stepRan[stage] then
        scheduleNextStep()
    end
    return co
end

local function schedule<A...>(name: TypeFuncs.KeyOf<Elements>, fn: (A...) -> (), ...: A...): thread
    return scheduleAt(name, "schedule", fn, ...)
end

local function scheduleBefore<A...>(name: TypeFuncs.KeyOf<Elements>, fn: (A...) -> (), ...: A...): thread
    return scheduleAt(name, "before", fn, ...)
end

local function scheduleAfter<A...>(name: TypeFuncs.KeyOf<Elements>, fn: (A...) -> (), ...: A...): thread
    return scheduleAt(name, "after", fn, ...)
end

local function defer<A...>(fn: (A...) -> (), ...: A...): thread
    return schedule("defer", fn, ...)
end

local function idle<A...>(fn: (A...) -> (), ...: A...): thread
    return schedule("idle", fn, ...)
end

local function waitFor(stage: TypeFuncs.KeyOf<Elements>, phase: TypeFuncs.KeyOf<Phases>?)
    local cor = coroutine.running()
    scheduleAt(stage, phase or "schedule", function(...)
        task.spawn(cor)
    end)
    coroutine.yield()
end

local function getCurrentStage(): TypeFuncs.KeyOf<Elements> | "sync"
    return currentStage
end

local function getCurrentStagePhase(): TypeFuncs.KeyOf<Phases> | "sync"
    return currentStagePhase
end

return table.freeze {
    idle = idle,
    defer = defer,
    step = step,
    schedule = schedule,
    scheduleBefore = scheduleBefore,
    scheduleAfter = scheduleAfter,
    waitFor = waitFor,
    getCurrentStage = getCurrentStage,
    getCurrentStagePhase = getCurrentStagePhase
}
