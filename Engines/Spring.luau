--!strict
--!native
---------------------------------------------------------------------
-- spr - Spring-driven motion library
--
-- Copyright (c) 2024 Fractality. All rights reserved.
-- Released under the MIT license.
--
-- Docs & license can be found at https://github.com/Fraktality/spr
--
-- API Summary:
--
-- spr.target(
--    Instance obj,
--    number dampingRatio,
--    number undampedFrequency,
--    dict<string, Variant> targetProperties)
--
--    Animates the given properties towardes the target values,
--    given damping ratio and undamped frequency.
--
--
-- spr.stop(
--    Instance obj[,
--    string property])
--
--    Stops the specified property on an Instance from animating.
--    If no property is specified, all properties of the Instance
--    will stop animating.
--
-- Visualizer: https://www.desmos.com/calculator/rzvw27ljh9
--
--
-- Modified especially for PeanutUI
-- Fixed some stuff, added some functions and changed color space
---------------------------------------------------------------------

local STRICT_RUNTIME_TYPES = true -- assert on parameter and property type mismatch
local SLEEP_OFFSET_SQ_LIMIT = (1/3840)^2 -- square of the offset sleep limit
local SLEEP_VELOCITY_SQ_LIMIT = 1e-2^2 -- square of the velocity sleep limit
local EPS = 1e-5 -- epsilon for stability checks around pathological frequency/damping values

local RunService: RunService = game:GetService("RunService")
const Oklab = require(script.Parent.Parent.Math.Oklab)

local rgbToOklab = Oklab.rgbToOklab
local oklabToRgb = Oklab.oklabToRgb

local pi = math.pi

local function magnitudeSq(vec: {number})
    local out = 0
    for _, v in vec do
        out += v^2
    end
    return out
end

local function distanceSq(vec0: {number}, vec1: {number})
    local out = 0
    for i0, v0 in vec0 do
        out += (vec1[i0] - v0)^2
    end
    return out
end

type TypeMetadata<T> = {
    springType: (dampingRatio: number, frequency: number, pos: number, typedat: TypeMetadata<T>, rawTarget: T) -> LinearSpring<T>,
    toIntermediate: (T) -> {number},
    fromIntermediate: ({number}) -> T,
}

-- Spring for an array of linear values
local LinearSpring = {}

type LinearSpring<T> = typeof(setmetatable({} :: {
    d: number,
    f: number,
    g: {number},
    p: {number},
    v: {number},
    typedat: TypeMetadata<T>,
    rawTarget: T,
}, LinearSpring))

do
    LinearSpring.__index = LinearSpring

    function LinearSpring.new<T>(dampingRatio: number, frequency: number, pos: T, rawGoal: T, typedat: any)
        local linearPos = typedat.toIntermediate(pos)
        return setmetatable(
            {
                d = dampingRatio,
                f = frequency,
                g = linearPos,
                p = linearPos,
                v = table.create(#linearPos, 0),
                typedat = typedat,
                rawGoal = rawGoal
            },
            LinearSpring
        )
    end

    function LinearSpring.setGoal<T>(self, goal: T)
        self.rawGoal = goal
        self.g = self.typedat.toIntermediate(goal)
    end

    function LinearSpring.setDampingRatio<T>(self: LinearSpring<T>, dampingRatio: number)
        self.d = dampingRatio
    end

    function LinearSpring.setFrequency<T>(self: LinearSpring<T>, frequency: number)
        self.f = frequency
    end

    function LinearSpring.canSleep<T>(self)
        if magnitudeSq(self.v) > SLEEP_VELOCITY_SQ_LIMIT then
            return false
        end

        if distanceSq(self.p, self.g) > SLEEP_OFFSET_SQ_LIMIT then
            return false
        end

        return true
    end

    function LinearSpring.step<T>(self: LinearSpring<T>, dt: number)
        -- Advance the spring simulation by dt seconds.
        -- Take the damped harmonic oscillator ODE:
        --    f^2*(X[t] - g) + 2*d*f*X'[t] + X''[t] = 0
        -- Where X[t] is position at time t, g is target position,
        -- f is undamped angular frequency, and d is damping ratio.
        -- Apply constant initial conditions:
        --    X[0] = p0
        --    X'[0] = v0
        -- Solve the IVP to get analytic expressions for X[t] and X'[t].
        -- The solution takes one of three forms for 0<=d<1, d=1, and d>1

        local d = self.d
        local f = self.f*(2*pi) -- Hz -> Rad/s
        local g = self.g
        local p = self.p
        local v = self.v

        if d == 1 then -- critically damped
            local q = math.exp(-f*dt)
            local w = dt*q

            local c0 = q + w*f
            local c2 = q - w*f
            local c3 = w*f*f

            for idx = 1, #p do
                local o = p[idx] - g[idx]
                p[idx] = o*c0 + v[idx]*w + g[idx]
                v[idx] = v[idx]*c2 - o*c3
            end

        elseif d < 1 then -- underdamped
            local q = math.exp(-d*f*dt)
            local c = math.sqrt(1 - d*d)

            local i = math.cos(dt*f*c)
            local j = math.sin(dt*f*c)

            -- Damping ratios approaching 1 can cause division by very small numbers.
            -- To mitigate that, group terms around z=j/c and find an approximation for z.
            -- Start with the definition of z:
            --    z = sin(dt*f*c)/c
            -- Substitute a=dt*f:
            --    z = sin(a*c)/c
            -- Take the Maclaurin expansion of z with respect to c:
            --    z = a - (a^3*c^2)/6 + (a^5*c^4)/120 + O(c^6)
            --    z ≈ a - (a^3*c^2)/6 + (a^5*c^4)/120
            -- Rewrite in Horner form:
            --    z ≈ a + ((a*a)*(c*c)*(c*c)/20 - c*c)*(a*a*a)/6

            local z
            if c > EPS then
                z = j/c
            else
                local a = dt*f
                z = a + ((a*a)*(c*c)*(c*c)/20 - c*c)*(a*a*a)/6
            end

            -- Frequencies approaching 0 present a similar problem.
            -- We want an approximation for y as f approaches 0, where:
            --    y = sin(dt*f*c)/(f*c)
            -- Substitute b=dt*c:
            --    y = sin(b*c)/b
            -- Now reapply the process from z.

            local y
            if f*c > EPS then
                y = j/(f*c)
            else
                local b = f*c
                y = dt + ((dt*dt)*(b*b)*(b*b)/20 - b*b)*(dt*dt*dt)/6
            end

            for idx = 1, #p do
                local o = p[idx] - g[idx]
                p[idx] = (o*(i + z*d) + v[idx]*y)*q + g[idx]
                v[idx] = (v[idx]*(i - z*d) - o*(z*f))*q
            end

        else -- overdamped
            local c = math.sqrt(d*d - 1)

            local r1 = -f*(d + c)
            local r2 = -f*(d - c)

            local ec1 = math.exp(r1*dt)
            local ec2 = math.exp(r2*dt)

            for idx = 1, #p do
                local o = p[idx] - g[idx]
                local co2 = (v[idx] - o*r1)/(2*f*c)
                local co1 = ec1*(o - co2)

                p[idx] = co1 + co2*ec2 + g[idx]
                v[idx] = co1*r1 + co2*ec2*r2
            end
        end

        return self.typedat.fromIntermediate(self.p)
    end
end

-- Type definitions
-- Transforms Roblox types into intermediate types, converting
-- between spaces as necessary to preserve perceptual linearity
local typeMetadata = {
    boolean = {
        springType = LinearSpring.new,

        toIntermediate = function(value)
            return {value and 1 or 0}
        end,

        fromIntermediate = function(value)
            return value[1] >= 0.5
        end,
    },

    number = {
        springType = LinearSpring.new,

        toIntermediate = function(value)
            return {value}
        end,

        fromIntermediate = function(value)
            return value[1]
        end,
    },

    NumberRange = {
        springType = LinearSpring.new,

        toIntermediate = function(value)
            return {value.Min, value.Max}
        end,

        fromIntermediate = function(value)
            return NumberRange.new(value[1], value[2])
        end,
    },

    UDim = {
        springType = LinearSpring.new,

        toIntermediate = function(value)
            return {value.Scale, value.Offset}
        end,

        fromIntermediate = function(value: {number})
            return UDim.new(value[1], math.round(value[2]))
        end,
    },

    UDim2 = {
        springType = LinearSpring.new,

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
        springType = LinearSpring.new,

        toIntermediate = function(value)
            return {value.X, value.Y}
        end,

        fromIntermediate = function(value: {number})
            return Vector2.new(value[1], value[2])
        end,
    },

    Color3 = {
        springType = LinearSpring.new,
        toIntermediate = rgbToOklab,
        fromIntermediate = oklabToRgb,
    },

    NumberSequence = {
        springType = LinearSpring.new,

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
        springType = LinearSpring.new,

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

type PropertyOverride = {
    [string]: {
        class: string,
        get: (any)->(),
        set: (any, any)->(),
    }
}

local function getProperty(instance: Instance, property: string): any
    return (instance :: any)[property]
end

local function setProperty(instance: Instance, property: string, value: any)
    (instance :: any)[property] = value
end

-- Frame loop
local springStates: {[Instance]: {[string]: any}} = {} -- {[instance] = {[property] = spring}
local completedCallbacks: {[Instance]: {() -> ()}} = {}
local destroyingConnections: {[Instance]: RBXScriptConnection} = {}

local function processSprings(springStates: typeof(springStates), dt: number)
    for instance, state in springStates do
        for propName, spring in state do
            if spring:canSleep() then
                state[propName] = nil
                setProperty(instance, propName, spring.rawGoal)
            else
                setProperty(instance, propName, spring:step(dt))
            end
        end

        if not next(state) then
            springStates[instance] = nil

            -- trigger completed callbacks when all properties finish animating
            local callbackList = completedCallbacks[instance]
            if callbackList then
                -- flush callback list before we run any callbacks in case
                -- one of the callbacks recursively adds another callback
                completedCallbacks[instance] = nil

                for _, callback in callbackList do
                    task.spawn(callback)
                end
            end
        end
    end
end

RunService.PreRender:Connect(function(dt)
    processSprings(springStates, dt)
end)

local function assertType(argNum: number, fnName: string, expectedType: string, value: any)
    if not expectedType:find(typeof(value)) then
        error(`bad argument #{argNum} to {fnName} ({expectedType} expected, got {typeof(value)})`, 3)
    end
end

-- API
local spr = {}

function spr.target(instance: Instance, dampingRatio: number, frequency: number, properties: {[string]: any})
    if STRICT_RUNTIME_TYPES then
        assertType(1, "spr.target", "Instance", instance)
        assertType(2, "spr.target", "number", dampingRatio)
        assertType(3, "spr.target", "number", frequency)
        assertType(4, "spr.target", "table", properties)
    end

    if dampingRatio ~= dampingRatio or dampingRatio < 0 then
        error(("expected damping ratio >= 0; got %.2f"):format(dampingRatio), 2)
    end

    if frequency ~= frequency or frequency < 0 then
        error(("expected undamped frequency >= 0; got %.2f"):format(frequency), 2)
    end

    local state = springStates[instance]
    if not state then
        state = {}
        springStates[instance] = state

        if not destroyingConnections[instance] then
            destroyingConnections[instance] = instance.Destroying:Once(function()
                springStates[instance] = nil
                completedCallbacks[instance] = nil
                destroyingConnections[instance] = nil
            end)
        end
    end

    for propName, propTarget in properties do
        local propValue = getProperty(instance, propName)

        if STRICT_RUNTIME_TYPES and typeof(propTarget) ~= typeof(propValue) then
            error(`bad property {propName} to spr.target ({typeof(propValue)} expected, got {typeof(propTarget)})`, 2)
        end

        -- Special case infinite frequency for an instantaneous change
        if frequency == math.huge then
            setProperty(instance, propName, propTarget)
            state[propName] = nil
            continue
        end

        local spring = state[propName]
        if not spring then
            local md = typeMetadata[typeof(propTarget)]
            if not md then
                error("unsupported type: " .. typeof(propTarget), 2)
            end

            spring = md.springType(dampingRatio, frequency, propValue, propTarget, md)
            state[propName] = spring
        end

        spring:setGoal(propTarget)
        spring:setDampingRatio(dampingRatio)
        spring:setFrequency(frequency)
    end

    if not next(state) then
        springStates[instance] = nil
    end
end

function spr.stop(instance: Instance, property: string?)
    if STRICT_RUNTIME_TYPES then
        assertType(1, "spr.stop", "Instance", instance)
        assertType(2, "spr.stop", "string|nil", property)
    end

    if property then
        local state = springStates[instance]
        if state then
            state[property] = nil
        end
    else
        springStates[instance] = nil
        completedCallbacks[instance] = nil
    end
end

function spr.completed(instance: Instance, callback: () -> ())
    if STRICT_RUNTIME_TYPES then
        assertType(1, "spr.completed", "Instance", instance)
        assertType(2, "spr.completed", "function", callback)
    end

    local callbackList = completedCallbacks[instance]
    if callbackList then
        table.insert(callbackList, callback)
    else
        completedCallbacks[instance] = {callback}
    end

    return function()
        local callbackList2 = completedCallbacks[instance]
        local index = table.find(callbackList2, callback)
        if callbackList2 and index then
            if #callbackList2 == 1 then
                completedCallbacks[instance] = nil
            else
                table.remove(callbackList2, index)
            end
        end
    end
end

function spr.isAnimating(instance: Instance, property: string): boolean
    local renderState = springStates[instance]
    return renderState ~= nil and renderState[property] ~= nil
end

return table.freeze(spr)