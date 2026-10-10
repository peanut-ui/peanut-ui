--!strict
--!optimize 2
const Animations = require(script.Parent.Parent.Types.Animations)
const Modifier = require(script.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Types.Utils)
const Context = require(script.Parent.Parent.Utils.Context)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Scheduler = require(script.Parent.Parent.Utils.Scheduler)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Units = require(script.Parent.Parent.Utils.Units)

local logger = Logging.getLogger("PeanutUI.Classes.Modifiers")

local counter = 0
local Modifiers = {}

local function defaultScaleFn<T>(obj: T, getOriginal: boolean?): T
    return obj
end

local freezeAndClear = Helpers.freezeAndClear

type TransformFn = (component: Modifier.Component, getProp: (string) -> any) -> any
type RbxTransformFn = (component: Modifier.Component, value: any) -> any
local function createModifier(
    name: string,
    className: string,
    properties: {[string]: any},
    linkedProperties: {[string]: {string} | string},
    propertyCalcFn: {[string]: TransformFn},
    setupFn: (Modifier.Component) -> ()?,
    rbxLinkBack_: {[string]: string}?,
    rbxLinkBackTransform_: {[string]: RbxTransformFn}?,
    scaleDependant: {string}?
): Modifier.Component
    counter += 1
    local id = counter

    local rbxLinkBack = rbxLinkBack_ or {}
    local rbxPropertyEvent: {[string]: RBXScriptConnection} = {}
    local rbxPropertyWatching: {[string]: number} = {}
    local rbxPropertyTransform: {[string]: RbxTransformFn} = rbxLinkBackTransform_ or {}

    local bucket = Context.createBucket("modifier")

    local modifier = {}
    modifier._typeName = "modifier"
    modifier._uniqueId = id
    modifier._componentName = name

    local object: UIComponent? = nil
    local modifierComponents: {[string]: Modifier.Component} = {}

    local scaleFn = defaultScaleFn

    local propertiesRefs: {[string]: Utils.Ref<any>} = {}
    local transitions: {[string]: Animations.Transition} = {}

    local animationsToPlay: {[any]: boolean} = {}
    local animations: {[any]: Animations.Animation} = {}
    local animationControlCache: {[any]: Animations.AnimationControl} = {}

    local cleanups: { RBXScriptConnection | () -> () } = {}

    local destroyed = false

    local rbxKeysMap: {[string]: {string}} = {}

    for rbxKey, keys in pairs(linkedProperties) do
        if typeof(keys) == "table" then
            for _, key in ipairs(keys) do
                if not rbxKeysMap[key] then rbxKeysMap[key] = {} end
                table.insert(rbxKeysMap[key], rbxKey)
            end
        else
            if not rbxKeysMap[keys] then rbxKeysMap[keys] = {} end
            table.insert(rbxKeysMap[keys], rbxKey)
        end
    end

    local function ensureNotDestroyed()
        if destroyed then
            logger.critical("Tried to access modifier after it was destroyed")
        end
    end

    function modifier.destroy()
        if destroyed then return end
        destroyed = true

        for _, cleanup in ipairs(cleanups) do
            if typeof(cleanup) == "RBXScriptConnection" then
                cleanup:Disconnect()
            else
                cleanup()
            end
        end

        for _, modifier in pairs(modifierComponents) do
            modifier.destroy()
        end

        if object then
            for rbxKey, transition in pairs(transitions) do
                transition.stop(object, rbxKey)
            end

            object:Destroy()
            object = nil
        end

        bucket.stop()

        if object then
            for _, animation in animations do
                animation.stop(object)
            end
        end

        freezeAndClear(animations)
        freezeAndClear(animationsToPlay)
        freezeAndClear(animationControlCache)

        freezeAndClear(cleanups)
        freezeAndClear(transitions)
        freezeAndClear(rbxKeysMap)
        freezeAndClear(propertiesRefs)
        freezeAndClear(modifierComponents)
    end

    function modifier.isDestroyed()
        return destroyed
    end

    -- For animations
    local function scale(value: any, getOriginal: boolean?): any
        return scaleFn(value, getOriginal)
    end

    function modifier.getAnimationControl(name: any): Animations.AnimationControl
        ensureNotDestroyed()
        do
            local cached = animationControlCache[name]
            if cached then
                return cached
            end
        end

        local animation = animations[name]
        if not animation then
            return nil :: any
        end

        local animationControl = {}
        animationControl._typeName = "animationControl"

        function animationControl.animate()
            ensureNotDestroyed()
            if object then
                animation.animate(object, scale)
                animationsToPlay[name] = nil
            else
                animationsToPlay[name] = true
            end
        end

        function animationControl.stop()
            ensureNotDestroyed()
            animationsToPlay[name] = nil
            if object then
                animation.stop(object)
            end
        end

        function animationControl.isRunning()
            ensureNotDestroyed()
            if object then
                return animation.isRunning(object)
            end
            return false
        end

        function animationControl.pause()
            ensureNotDestroyed()
            if object then
                animation.pause(object)
                animationsToPlay[name] = nil
            end
        end

        function animationControl.continue()
            ensureNotDestroyed()
            if object then
                animation.continue(object)
            end
        end

        table.freeze(animationControl)
        animationControlCache[name] = animationControl
        return animationControl
    end

    local function setAnimation(name: any, animation: Animations.Animation?, disableAutoPlay: boolean?)
        ensureNotDestroyed()

        if not animation then
            -- Hi
        elseif animation._typeName == "animation" then
            animation = animation
        else
            logger.error("Not animation was passed.")
        end

        animationsToPlay[name] = nil
        local oldAnimation = animations[name]
        if oldAnimation then
            if object and oldAnimation.isRunning(object) then
                oldAnimation.stop(object)
            end

            animations[name] = nil
        end

        if not animation then
            return
        end

        animations[name] = animation
        if disableAutoPlay ~= true then
            if object then
                animation.animate(object, scale)
            else
                animationsToPlay[name] = true
            end
        end
    end
    modifier.setAnimation = setAnimation

    local function setTransition(key: string, transition: Animations.Transition?)
        ensureNotDestroyed()

        local rbxKeys = rbxKeysMap[key]
        if not rbxKeys then
            return
        end

        for _, rbxKey in ipairs(rbxKeys) do
            local oldTransition = transitions[rbxKey]
            if oldTransition and object then
                oldTransition.stop(object :: Instance, rbxKey)
            end

            transitions[rbxKey] = transition
        end
    end
    modifier.setTransition = setTransition

    local function getProperty(key: any): any
        ensureNotDestroyed()
        local ref = propertiesRefs[key]
        if not ref then
            return nil :: any
        else
            return ref.getValue()
        end
    end

    local function syncRbxProperty(key: string)
        local rbxKey = rbxLinkBack[key]
        if not rbxKey then
            return
        end

        local ref = propertiesRefs[key]
        if not ref then
            propertiesRefs[key] = Ref.new(nil, nil, bucket)
            ref = propertiesRefs[key]
        end

        local value = (object :: any)[rbxKey]

        local transformFn = rbxPropertyTransform[key]
        if transformFn then
            value = transformFn(modifier :: any, value)
        end

        ref.setValue(value)
    end

    local function checkRbxPropertyEvent(key: string)
        if not object then
            return
        end

        local rbxKey = rbxLinkBack[key]
        if not rbxKey then
            return
        end

        local counter = rbxPropertyWatching[key]
        if counter and counter <= 0 then
            rbxPropertyWatching[key] = nil
            counter = nil
        end

        if counter == nil then
            if rbxPropertyEvent[key] then
                rbxPropertyEvent[key]:Disconnect()
                rbxPropertyEvent[key] = nil

                -- If signals are deferred it's better to sync property
                syncRbxProperty(key)
            end
        elseif not rbxPropertyEvent[key] then
            rbxPropertyEvent[key] = object:GetPropertyChangedSignal(rbxLinkBack[key]):Connect(function(value)
                if object and transitions[key] and transitions[key].isRunning(object, rbxKey) then
                    return
                end
                syncRbxProperty(key)
            end)
        end
    end

    local function setProperty(key: string, value: any | Utils.Ref<any>)
        ensureNotDestroyed()

        local ref = propertiesRefs[key]
        if not ref then
            propertiesRefs[key] = Ref.new(value, nil, bucket)
        else
            ref.setValue(value)
        end
    end

    modifier.setProperty = setProperty
    modifier.getProperty = getProperty

    local function observe(key: string, callback: (newValue: any) -> ...boolean?): () -> ()
        ensureNotDestroyed()

        local ref = propertiesRefs[key] :: Utils.Ref<any>
        if not ref then
            ref = Ref.new(nil, nil, bucket) :: Utils.Ref<any>
            propertiesRefs[key] = ref
        end

        if rbxLinkBack[key] then
            local counter = rbxPropertyWatching[key] or 0
            rbxPropertyWatching[key] = counter + 1

            checkRbxPropertyEvent(key)
        end

        local unwatch, id = ref.watch(callback, { bucket = bucket })

        local function onUnwatch()
            if rbxLinkBack[key] then
                local counter = rbxPropertyWatching[key] or 0
                rbxPropertyWatching[key] = counter - 1

                checkRbxPropertyEvent(key)
            end
        end

        ref.setOnUnwatch(id, onUnwatch)

        return unwatch
    end
    modifier.observe = observe

    function modifier.getRef(key: string): Utils.ProtectedRef<any>
        ensureNotDestroyed()

        local ref = propertiesRefs[key]
        if not ref then
            ref = Ref.new(nil, nil, bucket) :: Utils.Ref<any>
            propertiesRefs[key] = ref
        end

        local onWatch: (...any) -> ()? = nil
        local onUnwatch: () -> ()? = nil
        if rbxLinkBack[key] then
            onWatch = function()
                local counter = rbxPropertyWatching[key] or 0
                rbxPropertyWatching[key] = counter + 1

                checkRbxPropertyEvent(key)
            end
            onUnwatch = function()
                local counter = rbxPropertyWatching[key] or 0
                rbxPropertyWatching[key] = counter - 1

                checkRbxPropertyEvent(key)
            end
        end

        return Ref.makeProtected(ref, onWatch, onUnwatch)
    end

    function modifier._addCleanup(cleanup: RBXScriptConnection | () -> ())
        table.insert(cleanups, cleanup)
    end

    function modifier.getComponent()
        return object
    end

    local dirtyKeys: {[string]: boolean} = {}
    local function flush()
        if not object then
            return
        end

        local keysToFlush = dirtyKeys
        dirtyKeys = {}

        for name, _ in animationsToPlay do
            local animation = animations[name]
            if animation then
                animation.animate(object, scale)
                animationsToPlay[name] = nil
            end
        end

        for rbxKey, _ in pairs(keysToFlush) do
            local newValue
            local fn = propertyCalcFn[rbxKey]
            if fn then
                newValue = fn(modifier :: any, modifier.getProperty)
            else
                local property = linkedProperties[rbxKey]
                if typeof(property) == "table" then
                    logger.warn("Cannot set UIComponent property because there's more than 1 linked property")
                    continue
                else
                    newValue = getProperty(property)
                end
            end

            if newValue == Undefined then
                newValue = nil
            end

            if transitions[rbxKey] then
                transitions[rbxKey].animate(object, rbxKey, newValue)
            else
                (object :: any)[rbxKey] = newValue
            end
        end
    end

    local scheduled = false
    local function scheduleFlush()
        if destroyed then return end
        if scheduled then return end
        scheduled = true

        Scheduler.schedule("redraw", function()
            scheduled = false
            if destroyed then return end

            flush()
        end)
    end

    local function redraw()
        ensureNotDestroyed()

        for rbxKey, _ in pairs(linkedProperties) do
            dirtyKeys[rbxKey] = true
        end

        for _, modifier in pairs(modifierComponents) do
            modifier._redraw()
        end

        flush()
    end

    modifier._redraw = redraw

    function modifier._redrawScale()
        ensureNotDestroyed()

        if not scaleDependant then return end

        for _, rbxKey in ipairs(scaleDependant) do
            dirtyKeys[rbxKey] = true
        end

        flush()
    end

    function modifier.mountTo(to: Instance)
        if typeof(to) ~= "Instance" then
            logger.error("Object has to be Instance!")
        end

        if not object then
            object = Instance.new(className) :: UIComponent
            if typeof(object) ~= "Instance" or not object:IsA("UIComponent") then
                logger.error("Object has to be UIComponent!")
            end
        end

        (object :: UIComponent).Parent = to
        for _, modifier in pairs(modifierComponents) do
            modifier.mountTo(object :: UIComponent)
        end

        for key, _ in pairs(rbxPropertyWatching) do
            checkRbxPropertyEvent(key)
        end

        redraw()
    end

    function modifier.snapProperty(key: string, value: any | Utils.Ref<any>)
        ensureNotDestroyed()

        local rbxKeys = rbxKeysMap[key]
        if not rbxKeys then
            setProperty(key, value)
            return
        end

        local cachedTransitions: {[string]: Animations.Transition} = {}
        for _, rbxKey in ipairs(rbxKeys) do
            local cachedTransition = transitions[rbxKey]
            if not cachedTransition then
                continue
            end

            transitions[rbxKey] = nil

            if cachedTransition and object then
                cachedTransition.stop(object :: Instance, rbxKey)
            end

            cachedTransitions[rbxKey] = cachedTransition
        end

        setProperty(key, value)
        flush()

        for rbxKey, cachedTransition in pairs(cachedTransitions) do
            transitions[rbxKey] = cachedTransition
        end
    end

    local function setModifier(name: string, params: {[string]: any} | { {[string]: any} })
        ensureNotDestroyed()

        local modifierFactory: (props: {[string]: any}) -> Modifier.Component

        do
            local component = Modifiers.components[name]
            if not component then
                logger.warn("Modifier with name %s doesn't exist", name)
                return
            end

            if typeof(component) == "string" then
                component = Modifiers.components[component]
                if not component or typeof(component) == "string" then
                    return
                end
                modifierFactory = component
            else
                modifierFactory = component
            end
        end

        if typeof(params) == "table" and typeof(params[1]) == "table" then
            for i, config in ipairs(params :: { {[string]: any} }) do
                local stackKey = `{name}_{i}`

                if Helpers.removeUndefined(config) == nil then
                    local component = modifierComponents[stackKey]
                    if component then
                        component.destroy()
                        modifierComponents[stackKey] = nil
                    end
                    return
                end

                if not modifierComponents[stackKey] then
                    local newMod = modifierFactory(config) :: any
                    modifierComponents[stackKey] = newMod
                    if object then
                        newMod.mountTo(object)
                    end
                else
                    for k, v in pairs(config) do
                        modifierComponents[stackKey].setProperty(k, v)
                    end
                end
            end
        else
            local stackKey = `{name}_1`

            if Helpers.removeUndefined(params) == nil then
                local component = modifierComponents[stackKey]
                if component then
                    component.destroy()
                    modifierComponents[stackKey] = nil
                end
                return
            end

            if not modifierComponents[stackKey] then
                local newMod = modifierFactory(params :: {[string]: any}) :: any
                modifierComponents[stackKey] = newMod
                if object then newMod.mountTo(object) end
            else
                for k, v in pairs(params :: {[string]: any}) do
                    modifierComponents[stackKey].setProperty(k, v)
                end
            end
        end
    end

    modifier.setModifier = setModifier

    function modifier.getModifier(name: string, index: number?)
        return modifierComponents[`{name}_{index or 1}`]
    end

    function modifier.getScaleObjectFn()
        return scaleFn
    end

    function modifier.setScaleObjectFn(fn)
        scaleFn = fn or defaultScaleFn
    end

    for key, value in pairs(properties) do
        if propertiesRefs[key] and propertiesRefs[key].getValue() ~= nil then
            continue
        end

        if key == "gradient" then
            setModifier("gradient", value)
            continue
        end

        if key == "transitions" then
            for property, transition in value do
                setTransition(property, transition)
            end
            continue
        end

        if key == "animations" then
            for name, animation in value do
                setAnimation(name, animation)
            end
            continue
        end

        setProperty(key, value)
    end

    for rbxKey, keys in pairs(linkedProperties) do
        if typeof(keys) == "table" then
            for _, key in ipairs(keys) do
                observe(key, function()
                    dirtyKeys[rbxKey] = true
                    scheduleFlush()
                end)
            end
        else
            observe(keys, function()
                dirtyKeys[rbxKey] = true
                scheduleFlush()
            end)
        end
    end

    if setupFn then
        setupFn(modifier :: any)
    end

    return table.freeze(modifier :: any)
end

local function createConstructor(
    name: string,
    className: string,
    defaultProperties: {[string]: any},
    linkedProperties: {[string]: {string} | string},
    propertyCalcFn: {[string]: (component: Modifier.Component, getProp: (string) -> any) -> any},
    scaleDependant: {string}?,
    setupFn: (Modifier.Component) -> ()?,
    robloxLinkBack: {[string]: string}?,
    robloxLinkBackTransform: {[string]: (any) -> any}?
): (properties: {[string]: any}) -> Modifier.Component
    table.freeze(defaultProperties)
    table.freeze(linkedProperties)
    table.freeze(propertyCalcFn)

    return function(properties: {[string]: any})
        local newProperties = table.clone(defaultProperties)

        for key, value in pairs(properties) do
            newProperties[key] = value
        end

        for key, value in pairs(newProperties) do
            if type(value) == "function" and value == defaultProperties[key] then
                newProperties[key] = (value :: () -> any)()
            end
        end

        return createModifier(
            name,
            className,
            newProperties,
            linkedProperties,
            propertyCalcFn,
            setupFn,
            robloxLinkBack,
            robloxLinkBackTransform,
            scaleDependant
        )
    end
end


local function useUDim2(property: string)
    return function(c: Modifier.Component)
        local scaleFn = c.getScaleObjectFn()
        return scaleFn(Units.ToUDim2(c.getProperty(property) :: any))
    end
end

local function useUDim(property: string)
    return function(c: Modifier.Component)
        local scaleFn = c.getScaleObjectFn()
        return scaleFn(Units.ToUDim(c.getProperty(property) :: any))
    end
end


local function useEnum(enum: Enum, property: string)
    return function(c: Modifier.Component)
        return enum:FromName(c.getProperty(property) :: string)
    end
end

local function scale(property: string)
    return function(c: Modifier.Component)
        return c.getScaleObjectFn()(c.getProperty(property) :: Vector2)
    end
end

local function rbxScale(c: Modifier.Component, value: any)
    return c.getScaleObjectFn()(value, true)
end

Modifiers.createModifier = createModifier
Modifiers.createConstructor = createConstructor
Modifiers.components = {
    flex = createConstructor(
        "flex",
        "UIFlexItem",
        {
            mode = "None",
            lineAlignment = "Automatic",
            growRatio = 0,
            shrinkRatio = 0,
        },
        {
            FlexMode = "mode",
            ItemLineAlignment = "lineAlignment",
            GrowRatio = "growRatio",
            ShrinkRatio = "shrinkRatio",
        },
        {
            FlexMode = useEnum(Enum.UIFlexMode, "mode"),
            ItemLineAlignment = useEnum(Enum.ItemLineAlignment, "lineAlignment"),
        }
    ),
    cornerRadius = createConstructor(
        "cornerRadius",
        "UICorner",
        {
            all = function() return Units.Unit() end
        },
        {
            BottomLeftRadius = {"bottomLeft", "all"},
            BottomRightRadius = {"bottomRight", "all"},
            TopLeftRadius = {"topLeft", "all"},
            TopRightRadius = {"topRight", "all"},
        },
        {
            BottomLeftRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("bottomLeft") or getProp("all")
                ))
            end,
            BottomRightRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("bottomRight") or getProp("all")
                ))
            end,
            TopLeftRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("topLeft") or getProp("all")
                ))
            end,
            TopRightRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("topRight") or getProp("all")
                ))
            end
        },
        {  -- Scale dependant
            "BottomLeftRadius", "BottomRightRadius",
            "TopLeftRadius", "TopRightRadius"
        }
    ),
    padding = createConstructor(
        "padding",
        "UIPadding",
        {
            all = function() return Units.Unit() end
        },
        {
            PaddingLeft = {"left", "all"},
            PaddingRight = {"right", "all"},
            PaddingTop = {"top", "all"},
            PaddingBottom = {"bottom", "all"},
        },
        {
            PaddingLeft = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("left") or getProp("all")
                ))
            end,
            PaddingRight = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("right") or getProp("all")
                ))
            end,
            PaddingTop = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("top") or getProp("all")
                ))
            end,
            PaddingBottom = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return scale(Units.ToUDim(
                    getProp("bottom") or getProp("all")
                ))
            end
        },
        {  -- Scale dependant
            "PaddingLeft", "PaddingRight",
            "PaddingTop", "PaddingBottom"
        }
    ),
    stroke = createConstructor(
        "stroke",
        "UIStroke",
        {
            enabled = true,
            zIndex = 0,
            transparency = 0,
            color = Color3.new(1, 1, 1),
            thickness = 1,
            borderOffset = function() return Units.Unit() end,
            strokeMode = "Border",
            borderPosition = "Outer",
            lineJoinMode = "Round"
        },
        {
            Enabled = "enabled",
            ZIndex = "zIndex",
            Color = "color",
            Transparency = "transparency",
            Thickness = "thickness",
            BorderOffset = "borderOffset",
            ApplyStrokeMode = "strokeMode",
            BorderStrokePosition = "borderPosition",
            LineJoinMode = "lineJoinMode"
        },
        {
            BorderOffset = useUDim("borderOffset"),
            Thickness = scale("thickness"),
            ApplyStrokeMode = useEnum(Enum.ApplyStrokeMode, "strokeMode"),
            BorderStrokePosition = useEnum(Enum.BorderStrokePosition, "borderPosition"),
            LineJoinMode = useEnum(Enum.LineJoinMode, "lineJoinMode"),
        },
        { -- Scale dependant!
            "BorderOffset", "Thickness"
        }
    ),
    strokes = "stroke",
    gradient = createConstructor(
        "gradient",
        "UIGradient",
        {
            enabled = true,
            color = ColorSequence.new(Color3.new(1, 1, 1)),
            offset = Vector2.zero,
            scale = 1,
            rotation = 0,
            transparency = NumberSequence.new(0),
            tileMode = "Clamp",
            type = "Linear"
        },
        {
            Enabled = "enabled",
            Color = "color",
            Offset = "offset",
            Scale = "scale",
            Rotation = "rotation",
            Transparency = "transparency",
            TileMode = "tileMode",
            Type = "type"
        },
        {}
    ),
    shadow = createConstructor(
        "shadow",
        "UIShadow",
        {
            enabled = true,
            blurRadius = function() return Units.Unit() end,
            color = Color3.new(0, 0, 0),
            offset = function() return Units.Position() end,
            spread = function() return Units.Size() end,
            transparency = 0,
            zIndex = 0
        },
        {
            Enabled = "enabled",
            BlurRadius = "blurRadius",
            Color = "color",
            Offset = "offset",
            Spread = "spread",
            Transparency = "transparency",
            ZIndex = "zIndex"
        },
        {
            BlurRadius = useUDim("blurRadius"),
            Offset = useUDim2("offset"),
            Spread = useUDim2("spread")
        },
        {  -- Scale dependant :3
            "BlurRadius", "Offset", "Spread"
        }
    ),
    shadows = "shadow",
    list = createConstructor(
        "list",
        "UIListLayout",
        {
            gap = function() return Units.Unit() end,
            horizontal = false,
            sortByName = false,
            wraps = false,
            horizontalAlign = "Left",
            verticalAlign = "Top",
            horizontalFlex = "None",
            lineAlignment = "Automatic",
            absoluteContentSize = Vector2.zero
        },
        {
            Padding = "gap",
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            Wraps = "wraps",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            HorizontalFlex = "horizontalFlex",
            ItemLineAlignment = "lineAlignment"
        },
        {
            Padding = useUDim("gap"),
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            HorizontalFlex = useEnum(Enum.UIFlexAlignment, "horizontalFlex"),
            ItemLineAlignment = useEnum(Enum.ItemLineAlignment, "lineAlignment"),
            SortOrder = function(c)
                return if c.getProperty("sortByName") then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
            end,
            FillDirection = function(c)
                return if c.getProperty("horizontal") then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
            end
        },
        {  -- Scale dependant!!!!
            "Padding"
        },
        nil,
        {  -- Link back
            absoluteContentSize = "AbsoluteContentSize"
        },
        {  -- Scale
            absoluteContentSize = rbxScale
        }
    ),
    grid = createConstructor(
        "grid",
        "UIGridLayout",
        {
            gap = function() return Units.Size() end,
            cellSize = function() return Units.Size() end,
            horizontal = false,
            sortByName = false,
            fillDirectionMaxCells = 0,
            horizontalAlign = "Left",
            verticalAlign = "Top",
            startCorner = "TopLeft",
            absoluteContentSize = Vector2.zero
        },
        {
            CellPadding = "gap",
            CellSize = "cellSize",
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            FillDirectionMaxCells = "fillDirectionMaxCells",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            StartCorner = "startCorner"
        },
        {
            CellPadding = useUDim2("gap"),
            CellSize = useUDim2("cellSize"),
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            StartCorner = useEnum(Enum.StartCorner, "startCorner"),
            FillDirection = function(c)
                return if c.getProperty("horizontal") then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
            end,
            SortOrder = function(c)
                return if c.getProperty("sortByName") then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
            end
        },
        {  -- Scale dependant!!!
            "CellPadding", "CellSize"
        },
        nil,
        {
            absoluteContentSize = "AbsoluteContentSize"
        },
        {
            absoluteContentSize = rbxScale
        }
    ),
    table = createConstructor(
        "table",
        "UITableLayout",
        {
            horizontal = false,
            sortByName = false,
            horizontalAlign = "Left",
            verticalAlign = "Top",
            majorAxis = "RowMajor",
            gap = function() return Units.Size() end,
            absoluteContentSize = Vector2.zero
        },
        {
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            MajorAxis = "majorAxis",
            CellPadding = "gap"
        },
        {
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            MajorAxis = useEnum(Enum.TableMajorAxis, "majorAxis"),
            CellPadding = useUDim2("gap"),
            FillDirection = function(c)
                return if c.getProperty("horizontal") then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
            end,
            SortOrder = function(c)
                return if c.getProperty("sortByName") then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
            end
        },
        {  -- Scale dependant, again
            "CellPadding"
        },
        nil,
        {  -- Sync back
            absoluteContentSize = "AbsoluteContentSize"
        },
        {  -- Sync back transform
            absoluteContentSize = rbxScale
        }
    ),
    aspectRatio = createConstructor(
        "aspectRatio",
        "UIAspectRatioConstraint",
        {
            ratio = 1,
            type = "FitWithinMaxSize",
            dominantAxis = "Width"
        },
        {
            AspectRatio = "ratio",
            AspectType = "type",
            DominantAxis = "dominantAxis"
        },
        {
            AspectType = useEnum(Enum.AspectType, "type"),
            DominantAxis = useEnum(Enum.DominantAxis, "dominantAxis")
        }
    ),
    sizeConstraint = createConstructor(
        "sizeConstraint",
        "UISizeConstraint",
        {
            max = Vector2.zero,
            min = Vector2.zero
        },
        {
            MaxSize = "max",
            MinSize = "min"
        },
        {
            MaxSize = scale("max"),
            MinSize = scale("min")
        },
        {  -- Scale dependant kaboom
            "MaxSize", "MinSize"
        }
    ),
    textSizeConstraint = createConstructor(
        "textSizeConstraint",
        "UITextSizeConstraint",
        {
            max = 0,
            min = 0
        },
        {
            MaxTextSize = "max",
            MinTextSize = "min"
        },
        {
            MaxTextSize = scale("max"),
            MinTextSize = scale("min")
        },
        {  -- This is scale dependant, isn't this crazy?
            "MaxTextSize", "MinTextSize"
        }
    ),
    scale = createConstructor(
        "scale",
        "UIScale",
        {
            scale = 1
        },
        {
            Scale = "scale"
        },
        {}
    )
} :: {[string]: string | (properties: {[string]: any}) -> Modifier.Component}

return table.freeze(Modifiers)