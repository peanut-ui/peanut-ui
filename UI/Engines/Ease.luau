--!strict
--!optimize 2
-- Ease engine just for PeanutUI :33
-- Animation ONLY for UI objects... Not doing the work Spring made...
-- This should be enough for everything
-- Made by koeqaife!!

const RunService = game:GetService("RunService")
const Curves = require(script.Parent.Parent.Math.Curves)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Oklab = require(script.Parent.Parent.Math.Oklab)

local logger = Logging.getLogger("PeanutUI.Engines.Ease")

local rgbToOklab = Oklab.rgbToOklab
local oklabToRgb = Oklab.oklabToRgb

export type Curve = (number) -> number

type TypeTransform = {
    toIntermediate: (any) -> {number},
    fromIntermediate: ({number}) -> any
}

type AnimationState = {
    transform: TypeTransform,
    curve: Curve,

    from: {number},
    to: {number},

    elapsed: number,
    duration: number
}

type ObjectState = {
    properties: {[string]: AnimationState},
    onCompleted: {() -> ()},
    onCompletedProperty: {[string]: {() -> ()}},
}

local Ease = {}
Ease.Curves = Curves

local objectsState: {[Instance]: ObjectState} = {}

local typeTransforms: {[string]: TypeTransform} = {
	boolean = {
		toIntermediate = function(value)
			return {value and 1 or 0}
		end,

		fromIntermediate = function(value)
			return value[1] >= 0.5
		end,
	},

	number = {
		toIntermediate = function(value)
			return {value}
		end,

		fromIntermediate = function(value)
			return value[1]
		end,
	},

	NumberRange = {
		toIntermediate = function(value)
			return {value.Min, value.Max}
		end,

		fromIntermediate = function(value)
			return NumberRange.new(value[1], value[2])
		end,
	},

	UDim = {
		toIntermediate = function(value)
			return {value.Scale, value.Offset}
		end,

		fromIntermediate = function(value: {number})
			return UDim.new(value[1], math.round(value[2]))
		end,
	},

	UDim2 = {
		toIntermediate = function(value)
			local x = value.X
			local y = value.Y
			return {x.Scale, x.Offset, y.Scale, y.Offset}
		end,

		fromIntermediate = function(value: {number})
			return UDim2.new(value[1], math.round(value[2]), value[3], math.round(value[4]))
		end,
	},

	Vector2 = {
		toIntermediate = function(value)
			return {value.X, value.Y}
		end,

		fromIntermediate = function(value: {number})
			return Vector2.new(value[1], value[2])
		end,
	},

	Vector3 = {
        toIntermediate = function(value)
            return {value.X, value.Y, value.Z}
        end,

        fromIntermediate = function(value: {number})
            return Vector3.new(value[1], value[2], value[3])
        end,
    },

	Color3 = {
		toIntermediate = rgbToOklab,
		fromIntermediate = oklabToRgb,
	},

	NumberSequence = {
		toIntermediate = function(value: NumberSequence)
			local keypoints = value.Keypoints
			local first = keypoints[1]
			local last = keypoints[#keypoints]

			return {
				first.Time, first.Value,
				last.Time, last.Value,
			}
		end,

		fromIntermediate = function(value: {number})
			return NumberSequence.new({
				NumberSequenceKeypoint.new(value[1], value[2]),
				NumberSequenceKeypoint.new(value[3], value[4]),
			})
		end,
	},

	-- Only interpolates start and end keypoints
	ColorSequence = {
		toIntermediate = function(value)
			local keypoints = value.Keypoints

			local luv0 = rgbToOklab(keypoints[1].Value)
			local luv1 = rgbToOklab(keypoints[#keypoints].Value)

			return {
				luv0[1], luv0[2], luv0[3],
				luv1[1], luv1[2], luv1[3],
			}
		end,

		fromIntermediate = function(value: {number})
			return ColorSequence.new(
				oklabToRgb{value[1], value[2], value[3]},
				oklabToRgb{value[4], value[5], value[6]}
			)
		end,
	},
}

@native
local function process(dt: number)
	for object, state in objectsState do
		for property, animationState in state.properties do
			animationState.elapsed += dt

			local t = math.clamp(
				animationState.elapsed / animationState.duration,
				0,
				1
			)

			local alpha = animationState.curve(t)
			local intermediate = table.create(#animationState.from, 0)

			for index, from in animationState.from do
				local to = animationState.to[index]

				intermediate[index] = from + (to - from) * alpha
			end

			(object :: any)[property] = animationState.transform
				.fromIntermediate(intermediate)

			if t >= 1 then
				state.properties[property] = nil

                if state.onCompletedProperty[property] then
                    local onCompleted = state.onCompletedProperty[property]
                    state.onCompletedProperty[property] = nil

                    for _, callback in onCompleted do
                        task.spawn(callback)
                    end
                end
			end
		end

		if next(state.properties) == nil then
			objectsState[object] = nil

            if state.onCompleted then
                local onCompleted = state.onCompleted
                state.onCompleted = {}

                for _, callback in onCompleted do
                    task.spawn(callback)
                end
            end
		end
	end
end

RunService.PreRender:Connect(function(deltaTime)
	if next(objectsState) == nil then
		return
	end

	process(deltaTime)
end)

function Ease.target(object: Instance, property: string, to: any, duration: number, curve: Curve)
    local from = (object :: any)[property]

    if typeof(to) ~= typeof(from) then
        logger.error(`Object's property {property} had type {typeof(from)} while type {typeof(to)} was passed`)
    end

    if duration == 0 then
        (object :: any)[property] = to
        Ease.stop(object, property)
        return
    end

    local state = objectsState[object]
    if not state then
        state = {
            properties = {},
            onCompleted = {},
            onCompletedProperty = {}
        }
        objectsState[object] = state
    end

    local transform = typeTransforms[typeof(from)]
    if not transform then
        logger.error(`Type {typeof(from)} is not supported`)
    end

    state.properties[property] = {
        transform = transform,
        curve = curve,

        from = transform.toIntermediate(from),
        to = transform.toIntermediate(to),

        elapsed = 0,
        duration = duration
    }
end

function Ease.stop(object: Instance, property: string?)
    if property then
        local state = objectsState[object]
        if state then
            state.properties[property] = nil
            state.onCompletedProperty[property] = nil
			if not next(state.properties) then
				objectsState[object] = nil
			end
        end
    else
        objectsState[object] = nil
    end
end

function Ease.completed(object: Instance, callback: () -> (), property: string?)
    local state = objectsState[object]
    if not state then
        return
    end

    if property then
        local propertyList = state.onCompletedProperty[property]
        if not propertyList then
            propertyList = {}
            state.onCompletedProperty[property] = propertyList
        end

        table.insert(propertyList, callback)
    else
        table.insert(state.onCompleted, callback)
    end
end

function Ease.isAnimating(object: Instance, property: string?): boolean
    if property then
        local state = objectsState[object]
        if not state then
            return false
        end

        return state.properties[property] ~= nil
    else
        return objectsState[object] ~= nil
    end
end

return table.freeze(Ease)