--!strict
--!optimize 2
const Animations = require(script.Parent.Parent.Types.Animations)
const Modifier = require(script.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Types.Utils)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Units = require(script.Parent.Parent.Utils.Units)

local logger = Logging.getLogger("PeanutUI.Classes.Modifiers")

local counter = 0
local Modifiers = {}

local function defaultScaleFn<T>(obj: T, getOriginal: boolean?): T
    return obj
end

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
    rbxLinkBackTransform_: {[string]: RbxTransformFn}?
): Modifier.Component
    counter += 1
    local id = counter

    local rbxLinkBack = rbxLinkBack_ or {}
    local rbxPropertyEvent: {[string]: RBXScriptConnection} = {}
    local rbxPropertyWatching: {[string]: number} = {}
    local rbxPropertyTransform: {[string]: RbxTransformFn} = rbxLinkBackTransform_ or {}

    local modifier = {}
    modifier._typeName = "modifier"
    modifier._uniqueId = id
    modifier._componentName = name

    local object: UIComponent? = nil
    local modifierComponents: {[string]: Modifier.Component} = {}

    local scaleFn = defaultScaleFn

    local propertiesRefs: {[string]: Utils.Ref<any>} = {}
    local transitions: {[string]: Animations.Transition} = {}

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
        table.clear(cleanups)

        for _, ref in pairs(propertiesRefs) do
            ref.destroy()
        end

        if object then
            for rbxKey, transition in pairs(transitions) do
                transition.stop(object, rbxKey)
            end

            object:Destroy()
            object = nil
        end
        table.clear(transitions)
    end

    function modifier.isDestroyed()
        return destroyed
    end

    function modifier.setTransition(key: string, transition: Animations.Transition?)
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
            propertiesRefs[key] = Ref.new(nil)
            ref = propertiesRefs[key]
        end

        local value = (object :: any)[rbxKey]

        local transformFn = rbxPropertyTransform[key]
        if transformFn then
            value = transformFn(modifier :: any, value)
        end

        ref.setValue(value, true)
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
            propertiesRefs[key] = Ref.new(value)
        else
            ref.setValue(value, true)
        end
    end

    modifier.setProperty = setProperty
    modifier.getProperty = getProperty

    local function observe(key: string, callback: (newValue: any) -> ...boolean?): () -> ()
        ensureNotDestroyed()

        local ref = propertiesRefs[key]
        if not ref then
            ref = Ref.new(nil)
            propertiesRefs[key] = ref
        end

        if rbxLinkBack[key] then
            local counter = rbxPropertyWatching[key] or 0
            rbxPropertyWatching[key] = counter + 1

            checkRbxPropertyEvent(key)
        end

        local unwatch, id = ref.watch(callback)
        table.insert(cleanups, unwatch)

        local function onUnwatch()
            local index = table.find(cleanups, unwatch)
            if index then
                -- Swap and pop :3
                cleanups[index] = cleanups[#cleanups]
                cleanups[#cleanups] = nil
            end

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
            ref = Ref.new(nil) :: Utils.Ref<any>
            propertiesRefs[key] = ref
        end

        local onWatch: () -> ()? = nil
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

        local keysToFlush = table.clone(dirtyKeys)
        table.clear(dirtyKeys)

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

        task.defer(function()
            scheduled = false
            if destroyed then return end

            flush()
        end)
    end

    local function redraw()
        ensureNotDestroyed()

        for _, ref in pairs(propertiesRefs) do
            ref.notifyImmediate()
        end

        for _, modifier in pairs(modifierComponents) do
            modifier._redraw()
        end

        flush()
    end

    modifier._redraw = redraw

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
            if not component then return end

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
                        -- Linter was screaming at me ;-;
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
        fn = scaleFn or defaultScaleFn
    end

    for key, value in pairs(properties) do
        if propertiesRefs[key] and propertiesRefs[key].getValue() ~= nil then
            continue
        end

        if key == "gradient" then
            setModifier("gradient", value)
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

        return createModifier(
            name,
            className,
            newProperties,
            linkedProperties,
            propertyCalcFn,
            setupFn,
            robloxLinkBack,
            robloxLinkBackTransform
        )
    end
end

local function useEnum(enum: Enum, property: string)
    return function(c: Modifier.Component)
        return enum:FromName(c.getProperty(property) :: string)
    end
end

local function useUDim2(property: string)
    return function(c: Modifier.Component)
        return Units.ToUDim2(c.getProperty(property) :: any)
    end
end

local function _useUDim(property: string)
    return function(c: Modifier.Component)
        return Units.ToUDim(c.getProperty(property) :: any)
    end
end

local function scale(property: string)
    return function(c: Modifier.Component)
        return c.getScaleObjectFn()(c.getProperty(property) :: Vector2)
    end
end

local function rbxScale(c: Modifier.Component, value: any)
    return c.getScaleObjectFn()(value)
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
            px = 0,
            scale = 0
        },
        {
            BottomLeftRadius = {"bottomLeftScale", "bottomLeftPx", "px", "scale"},
            BottomRightRadius = {"bottomRightScale", "bottomRightPx", "px", "scale"},
            TopLeftRadius = {"topLeftScale", "topLeftPx", "px", "scale"},
            TopRightRadius = {"topRightScale", "topRightPx", "px", "scale"},
        },
        {
            BottomLeftRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("bottomLeftScale") or getProp("scale"),
                    scale(getProp("bottomLeftPx") or getProp("px"))
                )
            end,
            BottomRightRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("bottomRightScale") or getProp("scale"),
                    scale(getProp("bottomRightPx") or getProp("px"))
                )
            end,
            TopLeftRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("topLeftScale") or getProp("scale"),
                    scale(getProp("topLeftPx") or getProp("px"))
                )
            end,
            TopRightRadius = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("topRightScale") or getProp("scale"),
                    scale(getProp("topRightPx") or getProp("px"))
                )
            end
        }
    ),
    padding = createConstructor(
        "padding",
        "UIPadding",
        {
            px = 0,
            scale = 0
        },
        {
            PaddingLeft = {"leftScale", "leftPx", "px", "scale"},
            PaddingRight = {"rightScale", "rightPx", "px", "scale"},
            PaddingTop = {"topScale", "topPx", "px", "scale"},
            PaddingBottom = {"bottomScale", "bottomPx", "px", "scale"},
        },
        {
            PaddingLeft = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("leftScale") or getProp("scale"),
                    scale(getProp("leftPx") or getProp("px"))
                )
            end,
            PaddingRight = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("rightScale") or getProp("scale"),
                    scale(getProp("rightPx") or getProp("px"))
                )
            end,
            PaddingTop = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("topScale") or getProp("scale"),
                    scale(getProp("topPx") or getProp("px"))
                )
            end,
            PaddingBottom = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim.new(
                    getProp("bottomScale") or getProp("scale"),
                    scale(getProp("bottomPx") or getProp("px"))
                )
            end
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
            thicknessPx = 1,
            borderOffsetScale = 0,
            borderOffsetPx = 0,
            strokeMode = "Border",
            borderPosition = "Outer",
            lineJoinMode = "Round"
        },
        {
            Enabled = "enabled",
            ZIndex = "zIndex",
            Color = "color",
            Transparency = "transparency",
            Thickness = "thicknessPx",
            BorderOffset = {"borderOffsetScale", "borderOffsetPx"},
            ApplyStrokeMode = "strokeMode",
            BorderStrokePosition = "borderPosition",
            LineJoinMode = "lineJoinMode"
        },
        {
            BorderOffset = function(c: Modifier.Component, getProp)
                local scale = c.getScaleObjectFn()
                return UDim.new(
                    getProp("borderOffsetScale"),
                    scale(getProp("borderOffsetPx"))
                )
            end,
            Thickness = scale("thicknessPx"),
            ApplyStrokeMode = useEnum(Enum.ApplyStrokeMode, "strokeMode"),
            BorderStrokePosition = useEnum(Enum.BorderStrokePosition, "borderPosition"),
            LineJoinMode = useEnum(Enum.LineJoinMode, "lineJoinMode"),
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
            blurRadiusPx = 0,
            blurRadiusScale = 0,
            color = Color3.new(0, 0, 0),
            offset = Units.Position(),
            spread = Units.Size(),
            transparency = 0,
            zIndex = 0
        },
        {
            Enabled = "enabled",
            BlurRadius = {"blurRadiusPx", "blurRadiusScale"},
            Color = "color",
            Offset = "offset",
            Spread = "spread",
            Transparency = "transparency",
            ZIndex = "zIndex"
        },
        {
            BlurRadius = function(comp: Modifier.Component, getProp)
                return UDim.new(
                    getProp("blurRadiusScale"),
                    comp.getScaleObjectFn()(getProp("blurRadiusPx"))
                )
            end,
            Offset = useUDim2("offset"),
            Spread = useUDim2("spread")
        }
    ),
    shadows = "shadow",
    list = createConstructor(
        "list",
        "UIListLayout",
        {
            gapPx = 0,
            gapScale = 0,
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
            Padding = {"gapPx", "gapScale"},
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            Wraps = "wraps",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            HorizontalFlex = "horizontalFlex",
            ItemLineAlignment = "lineAlignment"
        },
        {
            Padding = function(comp: Modifier.Component, getProp)
                return UDim.new(
                    getProp("gapScale"),
                    comp.getScaleObjectFn()(getProp("gapPx"))
                )
            end,
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
        nil,
        {
            absoluteContentSize = "AbsoluteContentSize"
        },
        {
            absoluteContentSize = rbxScale
        }
    ),
    grid = createConstructor(
        "grid",
        "UIGridLayout",
        {
            cellGapPx = Vector2.zero,
            cellGapScale = Vector2.zero,
            cellSizePx = Vector2.zero,
            cellSizeScale = Vector2.zero,
            horizontal = false,
            sortByName = false,
            fillDirectionMaxCells = 0,
            horizontalAlign = "Left",
            verticalAlign = "Top",
            startCorner = "TopLeft",
            absoluteContentSize = Vector2.zero
        },
        {
            CellPadding = {"cellGapPx", "cellGapScale"},
            CellSize = {"cellSizePx", "cellSizeScale"},
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            FillDirectionMaxCells = "fillDirectionMaxCells",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            StartCorner = "startCorner"
        },
        {
            CellPadding = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim2.new(
                    getProp("cellGapScale").X,
                    scale(getProp("cellGapPx").X),
                    getProp("cellGapScale").Y,
                    scale(getProp("cellGapPx").Y)
                )
            end,
            CellSize = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim2.new(
                    getProp("cellSizeScale").X,
                    scale(getProp("cellSizePx").X),
                    getProp("cellSizeScale").Y,
                    scale(getProp("cellSizePx").Y)
                )
            end,
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
            gapPx = Vector2.zero,
            gapScale = Vector2.zero,
            absoluteContentSize = Vector2.zero
        },
        {
            FillDirection = "horizontal",
            SortOrder = "sortByName",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            MajorAxis = "majorAxis",
            CellPadding = {"gapPx", "gapScale"}
        },
        {
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            MajorAxis = useEnum(Enum.TableMajorAxis, "majorAxis"),
            CellPadding = function(comp: Modifier.Component, getProp)
                local scale = comp.getScaleObjectFn()
                return UDim2.new(
                    getProp("gapScale").X,
                    scale(getProp("gapPx").X),
                    getProp("gapScale").Y,
                    scale(getProp("gapPx").Y)
                )
            end,
            FillDirection = function(c)
                return if c.getProperty("horizontal") then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
            end,
            SortOrder = function(c)
                return if c.getProperty("sortByName") then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
            end
        },
        nil,
        {
            absoluteContentSize = "AbsoluteContentSize"
        },
        {
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

return Modifiers