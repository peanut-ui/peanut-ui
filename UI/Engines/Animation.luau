--!strict
--!optimize 2
-- Made for PeanutUI by koeqaife!
-- So this is continuous animations, very important!

const RunService = game:GetService("RunService")
const Animations = require(script.Parent.Parent.Types.Animations)

local Animation = {}

type Step = Animations.AnimationStep

local stepStates: {[Instance]: {[Step]: any}} = {}

local runningAnimations: {[Instance]: {[Step]: boolean}} = {}
local pausedAnimations: {[Instance]: {[Step]: boolean}} = {}
local onCompletedAnimations: {[Instance]: {[Step]: {() -> ()}}} = {}

local destroyingConnections: {[Instance]: RBXScriptConnection} = {}

@native
local function process(dt: number)
	for object, stepFuncs in runningAnimations do
        for fn, _ in stepFuncs do
            local objectState = stepStates[object]
            local stop = fn(object, dt, objectState and objectState[fn])
            if not stop then
                continue
            end

            stepFuncs[fn] = nil
            if objectState then
                objectState[fn] = nil
                if next(objectState) == nil then
                    stepStates[object] = nil
                end
            end

            local onCompletedObject = onCompletedAnimations[object]

            if onCompletedObject then
                local onCompletedStep = onCompletedObject[fn]
                if onCompletedStep then
                    onCompletedObject[fn] = nil

                    for _, fn in onCompletedStep do
                        task.spawn(fn)
                    end
                end
            end

            if next(stepFuncs) == nil then
                runningAnimations[object] = nil

                if not pausedAnimations[object] then
                    local conn = destroyingConnections[object]
                    if conn then
                        conn:Disconnect()
                        destroyingConnections[object] = nil
                    end
                end
            end
        end
	end
end

RunService.PreRender:Connect(process)

function Animation.start(object: Instance, step: Step, state: any?)
    local animations = runningAnimations[object]
    if not animations then
        animations = {}
        runningAnimations[object] = animations
    end

    local paused = pausedAnimations[object]
    if paused and paused[step] then
        paused[step] = nil
        if next(paused) == nil then
            pausedAnimations[object] = nil
        end
    end

    if state then
        local objectState = stepStates[object]
        if not objectState then
            objectState = {}
            stepStates[object] = objectState
        end

        objectState[step] = state
    end

    animations[step] = true

    if not destroyingConnections[object] then
        destroyingConnections[object] = object.Destroying:Once(function()
            stepStates[object] = nil
            runningAnimations[object] = nil
            destroyingConnections[object] = nil
            pausedAnimations[object] = nil
            onCompletedAnimations[object] = nil
        end)
    end
end

function Animation.stop(object: Instance, step: Step?)
    if step then
        local running = runningAnimations[object]
        if running then
            running[step] = nil
        end

        local paused = pausedAnimations[object]
        if paused then
            paused[step] = nil
        end

        local onCompleted = onCompletedAnimations[object]
        if onCompleted then
            onCompleted[step] = nil
            if next(onCompleted) == nil then
                onCompletedAnimations[object] = nil
            end
        end

        local objectState = stepStates[object]
        if objectState then
            objectState[step] = nil
            if next(objectState) == nil then
                stepStates[object] = nil
            end
        end

        local counter = 2
        if running then
            if next(running) == nil then
                runningAnimations[object] = nil
                counter -= 1
            end
        else
            counter -= 1
        end

        if paused then
            if next(paused) == nil then
                pausedAnimations[object] = nil
                counter -= 1
            end
        else
            counter -= 1
        end

        if counter <= 0 then
            if destroyingConnections[object] then
                destroyingConnections[object]:Disconnect()
                destroyingConnections[object] = nil
            end
        end
    else
        stepStates[object] = nil
        runningAnimations[object] = nil
        pausedAnimations[object] = nil
        onCompletedAnimations[object] = nil

        if destroyingConnections[object] then
            destroyingConnections[object]:Disconnect()
            destroyingConnections[object] = nil
        end
    end
end

function Animation.pause(object: Instance, step: Step?)
    if step then
        local animations = runningAnimations[object]
        if animations then
            if animations[step] then
                animations[step] = nil
                if next(animations) == nil then
                    runningAnimations[object] = nil
                end

                local paused = pausedAnimations[object]
                if not paused then
                    paused = {}
                    pausedAnimations[object] = paused
                end

                paused[step] = true
            end
        end
    else
        local animations = runningAnimations[object]
        if animations then
            local paused = pausedAnimations[object]
            if not paused then
                paused = {}
                pausedAnimations[object] = paused
            end

            for step, _ in runningAnimations[object] do
                paused[step] = true
            end
            runningAnimations[object] = nil
        end
    end
end

function Animation.continue(object: Instance, step: Step?)
    if step then
        local paused = pausedAnimations[object]
        if paused then
            if paused[step] then
                paused[step] = nil
                if next(paused) == nil then
                    pausedAnimations[object] = nil
                end

                local animations = runningAnimations[object]
                if not animations then
                    animations = {}
                    runningAnimations[object] = animations
                end

                animations[step] = true
            end
        end
    else
        local paused = pausedAnimations[object]
        if paused then
            local animations = runningAnimations[object]
            if not animations then
                animations = {}
                runningAnimations[object] = animations
            end

            for step, _ in paused do
                animations[step] = true
            end
            pausedAnimations[object] = nil
        end
    end
end

function Animation.isAnimating(object: Instance, step: Step?): boolean
    if step then
        local animations = runningAnimations[object]
        if not animations then
            return false
        end

        return animations[step] ~= nil
    else
        return runningAnimations[object] ~= nil
    end
end

function Animation.onCompleted(object: Instance, step: Step, callback: () -> ()): () -> ()
    local callbacks = onCompletedAnimations[object]
    if not callbacks then
        callbacks = {}
        onCompletedAnimations[object] = callbacks
    end

    local stepCallbacks = callbacks[step]
    if not stepCallbacks then
        stepCallbacks = {}
        callbacks[step] = stepCallbacks
    end

    table.insert(stepCallbacks, callback)

    return function()
        local index = table.find(stepCallbacks, callback)
        if index then
            table.remove(stepCallbacks, index)
        end
    end
end

function Animation.isRunning(object: Instance, step: Step?): boolean
    if step then
        local animations = runningAnimations[object]
        if not animations then
            return false
        end

        return animations[step] ~= nil
    else
        return runningAnimations[object] ~= nil
    end
end

return Animation