--!strict
--!optimize 2
const Animation = require(script.Parent.Parent.Engines.Animation)
const AnimationsType = require(script.Parent.Parent.Types.Animations)
const Logging = require(script.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Components.Animations")

local Animations = {}

function makeAnimation(step: AnimationsType.AnimationStep, properties: {string}, createState: ((any) -> any)?, expectType: string?): AnimationsType.Animation
    local animation = {}
    animation._typeName = "animation" :: "animation"

    function animation.animate(object: Instance)
        if expectType and (typeof(object) ~= "Instance" or not object:IsA(expectType)) then
            logger.error("Got unexpected type")
        end

        Animation.start(object, step, createState and createState(object))
    end

    function animation.stop(object: Instance)
        Animation.stop(object, step)
    end

    function animation.isRunning(object: Instance)
        return Animation.isRunning(object, step)
    end

    function animation.pause(object: Instance)
        Animation.pause(object, step)
    end

    function animation.continue(object: Instance)
        Animation.continue(object, step)
    end

    animation.properties = properties

    table.freeze(animation)

    return animation
end

Animations.makeAnimation = makeAnimation

function Animations.Spin(degreePerSecond: number): AnimationsType.Animation
    local function step(object: GuiObject, dt: number, state: {number})
        state[1] += degreePerSecond * dt
        object.Rotation = state[1]
    end

    local function createState(obj: GuiObject)
        return { obj.Rotation }
    end

    return makeAnimation(step, {"Rotation"}, createState, "GuiObject")
end

return Animations