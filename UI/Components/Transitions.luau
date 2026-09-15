--!strict
--!optimize 2
const Ease = require(script.Parent.Parent.Engines.Ease)
const Animations = require(script.Parent.Parent.Types.Animations)
const Curves = require(script.Parent.Parent.Utils.Curves)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Spring = require(script.Parent.Parent.Engines.Spring)

local logger = Logging.getLogger("PeanutUI.Components.Transitions")
local Transitions = {}

function Transitions.Spring(
    dampingRatio: number,
    frequency: number
): Animations.Transition
    local transition = {}
    transition._typeName = "transition" :: "transition"

    function transition.animate(obj: Instance, property: string, to: any)
        Spring.target(obj, dampingRatio, frequency, { [property] = to })
    end

    function transition.stop(obj: Instance, property: string?)
        Spring.stop(obj, property)
    end

    function transition.isRunning(obj: Instance, property: string): boolean
        return Spring.isAnimating(obj, property)
    end

    return table.freeze(transition)
end

function Transitions.Ease(
    duration: number,
    curve: (keyof<typeof(Curves)> | (number) -> number)?
): Animations.Transition
    local curveNameOrFn = curve or "Ease"
    local curveFn: (number) -> number
    if type(curveNameOrFn) == "function" then
        curveFn = curveNameOrFn
    else
        curveFn = (Curves :: any)[curveNameOrFn]
        if not curveFn then
            logger.error("No curve with name %s was found", curveNameOrFn)
        end
    end

    local transition = {}
    transition._typeName = "transition" :: "transition"

    function transition.animate(obj: Instance, property: string, to: any)
        Ease.target(obj, property, to, duration, curveFn)
    end

    function transition.stop(obj: Instance, property: string?)
        Ease.stop(obj, property)
    end

    function transition.isRunning(obj: Instance, property: string): boolean
        return Ease.isAnimating(obj, property)
    end


    return table.freeze(transition)
end

function Transitions.EaseCubicBezier(
    duration: number,
    x1: number,
    y1: number,
    x2: number,
    y2: number
): Animations.Transition
    local curveFn = Curves.cubicBezier(x1, y1, x2, y2)

    local transition = {}
    transition._typeName = "transition" :: "transition"

    function transition.animate(obj: Instance, property: string, to: any)
        Ease.target(obj, property, to, duration, curveFn)
    end

    function transition.stop(obj: Instance, property: string?)
        Ease.stop(obj, property)
    end

    function transition.isRunning(obj: Instance, property: string): boolean
        return Ease.isAnimating(obj, property)
    end

    return table.freeze(transition)
end

return Transitions