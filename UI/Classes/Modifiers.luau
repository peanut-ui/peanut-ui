--!strict
--!optimize 2
const Animations = require(script.Parent.Parent.Types.Animations)
const Modifier = require(script.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Types.Utils)
const State = require(script.Parent.Parent.State)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Units = require(script.Parent.Parent.Utils.Units)

local logger = Logging.getLogger("PeanutUI.Classes.Modifiers")

local counter = 0
local Modifiers = {}

local function createModifier(
    name: string,
    className: string,
    properties: {[string]: any},
    linkedProperties: {[string]: {string} | string},
    propertyCalcFn: {[string]: (component: Modifier.Component, getProp: (string) -> any) -> any},
    setupFn: (Modifier.Component) -> ()?
): Modifier.Component
    counter += 1
    local id = counter

    local modifier = {}
    modifier._typeName = "modifier"
    modifier._uniqueId = id
    modifier._componentName = name

    local object: UIComponent? = nil

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

    local function observe(key: string, callback: (newValue: any) -> ...boolean): () -> ()
        ensureNotDestroyed()

        local ref = propertiesRefs[key]
        if not ref then
            propertiesRefs[key] = Ref.new(nil)
            ref = propertiesRefs[key]
        end

        local unwatch = ref.watch(callback)
        table.insert(cleanups, unwatch)

        return function()
            unwatch()
            local index = table.find(cleanups, unwatch)
            if index then
                -- Swap and pop :3
                cleanups[index] = cleanups[#cleanups]
                cleanups[#cleanups] = nil
            end
        end
    end
    modifier.observe = observe

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
                newValue = fn(modifier, modifier.getProperty)
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

    for key, value in pairs(properties) do
        if propertiesRefs[key] and propertiesRefs[key].getValue() then
            continue
        end

        if typeof(value) == "table" then
            value = table.clone(value)
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
        setupFn(modifier)
    end

    return table.freeze(modifier)
end

local function createConstructor(
    name: string,
    className: string,
    defaultProperties: {[string]: any},
    linkedProperties: {[string]: {string} | string},
    propertyCalcFn: {[string]: (component: Modifier.Component, getProp: (string) -> any) -> any},
    setupFn: (Modifier.Component) -> ()?
): (properties: {[string]: any}) -> Modifier.Component
    table.freeze(defaultProperties)
    table.freeze(linkedProperties)
    table.freeze(propertyCalcFn)

    return function(properties: {[string]: any})
        local newProperties = table.clone(defaultProperties)

        for key, value in pairs(properties) do
            newProperties[key] = value
        end

        return createModifier(name, className, newProperties, linkedProperties, propertyCalcFn)
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

local function useUDim(property: string)
    return function(c: Modifier.Component)
        return Units.ToUDim(c.getProperty(property) :: any)
    end
end

local function scalePx(property: string)
    return function(c: Modifier.Component)
        return State.scalePx(c.getProperty(property) :: number)
    end
end

local function scaleVector2(property: string)
    return function(c: Modifier.Component)
        return State.scaleVector2(c.getProperty(property) :: Vector2)
    end
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
            BottomLeftRadius = function(comp, getProp)
                return UDim.new(
                    getProp("bottomLeftScale") or getProp("scale"),
                    State.scalePx(getProp("bottomLeftPx") or getProp("px"))
                )
            end,
            BottomRightRadius = function(comp, getProp)
                return UDim.new(
                    getProp("bottomRightScale") or getProp("scale"),
                    State.scalePx(getProp("bottomRightPx") or getProp("px"))
                )
            end,
            TopLeftRadius = function(comp, getProp)
                return UDim.new(
                    getProp("topLeftScale") or getProp("scale"),
                    State.scalePx(getProp("topLeftPx") or getProp("px"))
                )
            end,
            TopRightRadius = function(comp, getProp)
                return UDim.new(
                    getProp("topRightScale") or getProp("scale"),
                    State.scalePx(getProp("topRightPx") or getProp("px"))
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
            PaddingLeft = function(comp, getProp)
                return UDim.new(
                    getProp("leftScale") or getProp("scale"),
                    State.scalePx(getProp("leftPx") or getProp("px"))
                )
            end,
            PaddingRight = function(comp, getProp)
                return UDim.new(
                    getProp("rightScale") or getProp("scale"),
                    State.scalePx(getProp("rightPx") or getProp("px"))
                )
            end,
            PaddingTop = function(comp, getProp)
                return UDim.new(
                    getProp("topScale") or getProp("scale"),
                    State.scalePx(getProp("topPx") or getProp("px"))
                )
            end,
            PaddingBottom = function(comp, getProp)
                return UDim.new(
                    getProp("bottomScale") or getProp("scale"),
                    State.scalePx(getProp("bottomPx") or getProp("px"))
                )
            end
        }
    ),
    stroke = createConstructor(
        "stroke",
        "UIStroke",
        {
            enabled = true,
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
            BorderOffset = function(_, getProp)
                return UDim.new(
                    getProp("borderOffsetScale"),
                    State.scalePx(getProp("borderOffsetPx"))
                )
            end,
            Thickness = scalePx("thicknessPx"),
            ApplyStrokeMode = useEnum(Enum.ApplyStrokeMode, "strokeMode"),
            BorderStrokePosition = useEnum(Enum.BorderStrokePosition, "borderPosition"),
            LineJoinMode = useEnum(Enum.LineJoinMode, "lineJoinMode"),
        }
    ),
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
            BlurRadius = function(_, getProp)
                return UDim.new(
                    getProp("blurRadiusScale"),
                    State.scalePx(getProp("blurRadiusPx"))
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
            itemLineAlign = "Auto"
        },
        {
            Gap = {"gapPx", "gapScale"},
            Horizontal = "horizontal",
            SortByName = "sortByName",
            Wraps = "wraps",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            HorizontalFlex = "horizontalFlex",
            ItemLineAlignment = "itemLineAlign"
        },
        {
            Gap = function(_, getProp)
                return UDim.new(
                    getProp("gapScale"),
                    State.scalePx(getProp("gapPx"))
                )
            end,
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            HorizontalFlex = useEnum(Enum.UIFlexAlignment, "horizontalFlex"),
            ItemLineAlignment = useEnum(Enum.ItemLineAlignment, "itemLineAlign")
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
            startCorner = "TopLeft"
        },
        {
            CellPadding = {"cellGapPx", "cellGapScale"},
            CellSize = {"cellSizePx", "cellSizeScale"},
            Horizontal = "horizontal",
            SortByName = "sortByName",
            FillDirectionMaxCells = "fillDirectionMaxCells",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            StartCorner = "startCorner"
        },
        {
            CellPadding = function(_, getProp)
                return UDim2.new(
                    getProp("cellGapScale").X,
                    State.scalePx(getProp("cellGapPx").X),
                    getProp("cellGapScale").Y,
                    State.scalePx(getProp("cellGapPx").Y)
                )
            end,
            CellSize = function(_, getProp)
                return UDim2.new(
                    getProp("cellSizeScale").X,
                    State.scalePx(getProp("cellSizePx").X),
                    getProp("cellSizeScale").Y,
                    State.scalePx(getProp("cellSizePx").Y)
                )
            end,
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            StartCorner = useEnum(Enum.StartCorner, "startCorner")
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
            gapScale = Vector2.zero
        },
        {
            Horizontal = "horizontal",
            SortByName = "sortByName",
            HorizontalAlignment = "horizontalAlign",
            VerticalAlignment = "verticalAlign",
            MajorAxis = "majorAxis",
            CellPadding = {"gapPx", "gapScale"}
        },
        {
            HorizontalAlignment = useEnum(Enum.HorizontalAlignment, "horizontalAlign"),
            VerticalAlignment = useEnum(Enum.VerticalAlignment, "verticalAlign"),
            MajorAxis = useEnum(Enum.TableMajorAxis, "majorAxis"),
            CellPadding = function(_, getProp)
                return UDim2.new(
                    getProp("gapScale").X,
                    State.scalePx(getProp("gapPx").X),
                    getProp("gapScale").Y,
                    State.scalePx(getProp("gapPx").Y)
                )
            end
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
            MaxSize = scaleVector2("max"),
            MinSize = scaleVector2("min")
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
            MaxTextSize = scalePx("max"),
            MinTextSize = scalePx("min")
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