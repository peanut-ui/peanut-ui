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

function Animations.Float(distance: number, cyclesPerSecond: number): AnimationsType.Animation
    type State = { phase: number, position: UDim2 }

    local function step(object: GuiObject, dt: number, state: State)
        state.phase += cyclesPerSecond * math.pi * 2 * dt
        local offset = math.sin(state.phase) * distance
        local base = state.position

        object.Position = UDim2.new(
            base.X.Scale,
            base.X.Offset,
            base.Y.Scale,
            base.Y.Offset + offset
        )
    end

    local function createState(object: GuiObject): State
        return {
            phase = 0,
            position = object.Position,
        }
    end

    return makeAnimation(step, {"Position"}, createState, "GuiObject")
end

function Animations.Swing(degrees: number, cyclesPerSecond: number): AnimationsType.Animation
    type State = { phase: number, rotation: number }

    local function step(object: GuiObject, dt: number, state: State)
        state.phase += cyclesPerSecond * math.pi * 2 * dt
        object.Rotation = state.rotation + math.sin(state.phase) * degrees
    end

    local function createState(object: GuiObject): State
        return {
            phase = 0,
            rotation = object.Rotation,
        }
    end

    return makeAnimation(step, {"Rotation"}, createState, "GuiObject")
end

function Animations.PulseSize(scale: number, cyclesPerSecond: number): AnimationsType.Animation
    type State = { phase: number, size: UDim2 }

    local function step(object: GuiObject, dt: number, state: State)
        state.phase += cyclesPerSecond * math.pi * 2 * dt
        local multiplier = 1 + math.sin(state.phase) * scale
        local base = state.size

        object.Size = UDim2.new(
            base.X.Scale * multiplier,
            base.X.Offset * multiplier,
            base.Y.Scale * multiplier,
            base.Y.Offset * multiplier
        )
    end

    local function createState(object: GuiObject): State
        return {
            phase = 0,
            size = object.Size,
        }
    end

    return makeAnimation(step, {"Size"}, createState, "GuiObject")
end

function Animations.PulseNumber(
    property: string,
    minimum: number,
    maximum: number,
    cyclesPerSecond: number
): AnimationsType.Animation
    local function step(object: GuiObject, dt: number, state: {number})
        state[1] += cyclesPerSecond * math.pi * 2 * dt
        local midpoint = (minimum + maximum) / 2
        local amplitude = (maximum - minimum) / 2
        (object :: any)[property] = midpoint + math.sin(state[1]) * amplitude
    end

    local function createState(object: GuiObject)
        if typeof((object :: any)[property]) ~= "number" then
            logger.error("Property %s is not a number, can't start animation", property)
        end
        return {0}
    end

    return makeAnimation(step, {property}, createState, "GuiObject")
end

function Animations.ColorCycle(property: string, cyclesPerSecond: number): AnimationsType.Animation
    type State = { hue: number, saturation: number, value: number }

    local function step(object: GuiObject, dt: number, state: State)
        state.hue = (state.hue + cyclesPerSecond * dt) % 1
        (object :: any)[property] = Color3.fromHSV(state.hue, state.saturation, state.value)
    end

    local function createState(object: GuiObject)
        if typeof((object :: any)[property]) ~= "Color3" then
            logger.error("Property %s is not a Color3, can't start animation", property)
        end
        local hue, saturation, value = (object :: any)[property]:ToHSV()

        return {
            hue = hue,
            saturation = saturation,
            value = value,
        }
    end

    return makeAnimation(step, {property}, createState, "GuiObject")
end

return Animations