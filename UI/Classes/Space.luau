--!strict
--!optimize 2
const Players = game:GetService("Players")
const Widget = require(script.Parent.Parent.Classes.Widget)
const Children = require(script.Parent.Parent.Classes.WidgetFeatures.Children)
const State = require(script.Parent.Parent.State)
const SpaceType = require(script.Parent.Parent.Types.Space)
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)
const Utils = require(script.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Types.Widget)
const Events = require(script.Parent.Parent.Utils.Events)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Hooks = require(script.Parent.Parent.Utils.Hooks)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Signals = require(script.Parent.Parent.Utils.Signals)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Units = require(script.Parent.Parent.Utils.Units)

local logger = Logging.getLogger("PeanutUI.Classes.Space")

local Space = {}

local function linkProperties(
    widget: SpaceType.InternalInterface,
    properties: {[string]: string},
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: (boolean | (any) -> any)?}?,
    readonly: {[string]: boolean?}?
)
    local link = widget._linkProperty
    for name, property in properties do
        link(
            name :: any,
            property,
            transformFn and transformFn[name],
            syncWithObject and syncWithObject[name],
            readonly and readonly[name]
        )
    end
end

local scaleFunctions: {
    [string]: (scaleFunction: WidgetType.ScaleCallback, obj: any, getOriginal: boolean?) -> any
} = {
    -- Roblox types
    Vector2 = function(scaleFunction: WidgetType.ScaleCallback, obj: Vector2, getOriginal: boolean?): Vector2
        return Vector2.new(
            scaleFunction(obj.X, getOriginal),
            scaleFunction(obj.Y, getOriginal)
        )
    end,
    UDim2 = function(scaleFunction: WidgetType.ScaleCallback, obj: UDim2, getOriginal: boolean?): UDim2
        return UDim2.new(
            obj.X.Scale,
            scaleFunction(obj.X.Offset, getOriginal),
            obj.Y.Scale,
            scaleFunction(obj.Y.Offset, getOriginal)
        )
    end,
    UDim = function(scaleFunction: WidgetType.ScaleCallback, obj: UDim, getOriginal: boolean?): UDim
        return UDim.new(
            obj.Scale,
            scaleFunction(obj.Offset, getOriginal)
        )
    end,

    -- PeanutUI types
    size = function(scaleFunction: WidgetType.ScaleCallback, size: Utils.Size, getOriginal: boolean?): Utils.Size
        return Units.Size(
            scaleFunction(size.width, getOriginal),
            scaleFunction(size.height, getOriginal),
            size.widthScale,
            size.heightScale
        )
    end,
    position = function(scaleFunction: WidgetType.ScaleCallback, pos: Utils.Position, getOriginal: boolean?): Utils.Position
        return Units.Position(
            scaleFunction(pos.x, getOriginal),
            scaleFunction(pos.y, getOriginal),
            pos.xScale,
            pos.yScale
        )
    end,
    unit = function(scaleFunction: WidgetType.ScaleCallback, unit: Utils.Unit, getOriginal: boolean?): Utils.Unit
        return Units.Unit(
            scaleFunction(unit.px, getOriginal),
            unit.scale
        )
    end,

    number = function(scaleFunction: WidgetType.ScaleCallback, px: number, getOriginal: boolean?): number
        return scaleFunction(px, getOriginal)
    end
}

local function newSpace(
    name: string,
    registry: {[string]: any},
    createObjectFn: () -> LayerCollector,
    linkedProperties: {[string]: string},
    properties: {[string]: any},
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: (boolean | (any) -> any)?}?,
    readonly: {[string]: boolean?}?
): SpaceType.Interface
    if registry[name] then
        logger.error(`Cannot create space with existing name: {name}`)
    end

    local signals = Signals.new()

    local scaleFunction = function(px: number, getOriginal: boolean?)
        return px
    end
    local stopScale: () -> ()? = nil

    local function scaleObject<T>(obj: T, getOriginal: boolean?): T
        if typeof(obj) == "table" then
            local fn = scaleFunctions[(obj :: any)._typeName or ""]

            if not fn then
                return obj :: any
            else
                return fn(scaleFunction, obj, getOriginal)
            end
        else
            local fn = scaleFunctions[typeof(obj)]

            if not fn then
                return obj :: any
            else
                return fn(scaleFunction, obj, getOriginal)
            end
        end
    end

    local widget = Widget.new({
        properties = properties,
        defaultSetupOverride = function(widget: SpaceType.InternalInterface)
            widget._typeName = "space"
            widget._widgetLike = true
            widget._widgetName = name
            widget._spaceName = name
            widget._isSpaceLike = true

            widget._createObject = function()
                return
            end

            local newObject = createObjectFn()
            newObject.ResetOnSpawn = false
            newObject:SetAttribute("_uniqueId", widget._uniqueId)
            widget._setObject(newObject)

            local player = Players.LocalPlayer
            local existingPlayerGui = player:FindFirstChild("PlayerGui")
            if existingPlayerGui then
                newObject.Parent = player.PlayerGui
            else
                task.spawn(function()
                    -- 5 * 12 = 1 minute
                    for i = 1, 12 do
                        if not player or not player.Parent then
                            return
                        end
                        local playerGui = player:WaitForChild("PlayerGui", 5)
                        if not playerGui then
                            logger.warn("Getting PlayerGui timed out, trying again...")
                        else
                            newObject.Parent = playerGui
                            return
                        end
                    end

                    signals.fire("PlayerGuiFailed")
                    logger.critical("Could not get PlayerGui!")
                end)
            end

            local link = widget._linkProperty
            linkProperties(
                widget,
                linkedProperties,
                transformFn,
                syncWithObject,
                readonly
            )

            link("name", "Name")
            link("visible", "Enabled")
            link("zIndexBehavior", "ZIndexBehavior")
            link("absoluteSize", "AbsoluteSize", nil, function(v)
                return scaleObject(v, true)
            end, true)
            link("absolutePosition", "AbsolutePosition", nil, function(v)
                return scaleObject(v, true)
            end, true)
            link("absoluteRotation" :: "absoluteRotation", "AbsoluteRotation", nil, nil, true)

            widget._redraw()
        end
    -- Idk why but linter says it's { [string]: any } and not args which is weird
    } :: any, {
        parenting = true,
        transitions = true,
        animations = true
    })
    local widgetInternal = (widget :: any) :: SpaceType.InternalInterface

    widgetInternal.signals = signals
    widgetInternal.scaleObject = scaleObject

    function widgetInternal.changeScaleFn(fn: WidgetType.ScaleFn)
        if stopScale then
            stopScale()
            stopScale = nil
        end

        if typeof(fn) == "function" then
            scaleFunction = fn
        elseif typeof(fn) == "table" then
            scaleFunction = fn.fn
            stopScale = fn.stop
        else
            logger.error("Type for scale function was not table or number!")
        end

        signals.fire("ScaleChanged")
    end

    widgetInternal._addCleanup(function()
        if registry[name] == widgetInternal then
            registry[name] = nil
        end

        if stopScale then
            stopScale()
            stopScale = nil
        end
    end)

    registry[name] = widget

    return widgetInternal
end

local function createConstructor(
    registry: {[string]: any},
    createObjectFn: () -> LayerCollector,
    linkedProperties: {[string]: string},
    defaultProperties: any,
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: (boolean | (any) -> any)?}?,
    readonly: {[string]: boolean?}?
): (string, {[string]: any}?) -> SpaceType.Interface
    return function(name, props)
        local properties = props and table.clone(props) or {}
        for key, value in defaultProperties do
            if properties[key] == nil then
                properties[key] = value
            end
        end

        return newSpace(
            name,
            registry,
            createObjectFn,
            linkedProperties,
            properties,
            transformFn,
            syncWithObject,
            readonly
        )
    end
end

-- ScreenSpace -- start --
local registeredScreenSpaces: {[string]: SpaceType.ScreenSpace} = {}
local defaultScreenProperties = {
    name = "ScreenSpace",
    absoluteSize = Vector2.zero,
    absolutePosition = Vector2.zero,
    absoluteRotation = 0,
    zIndexBehavior = Enum.ZIndexBehavior.Sibling,
    visible = true,

    displayOrder = 0,
    clipToDeviceSafeArea = true,
    ignoreGuiInset = false,
    safeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension,
    screenInsets = Enum.ScreenInsets.CoreUISafeInsets
}

table.freeze(defaultScreenProperties)

Space.createScreenSpace = createConstructor(
    registeredScreenSpaces,
    function(): LayerCollector
        return Instance.new("ScreenGui")
    end,
    {
        displayOrder = "DisplayOrder",
        clipToDeviceSafeArea = "ClipToDeviceSafeArea",
        ignoreGuiInset = "IgnoreGuiInset",
        safeAreaCompatibility = "SafeAreaCompatibility",
        screenInsets = "ScreenInsets"
    },
    defaultScreenProperties
) :: (name: string, props: TypeFuncs.Partial<SpaceType.ScreenSpaceProps>?) -> SpaceType.ScreenSpace

function Space.getScreenSpace(name: string): SpaceType.ScreenSpace
    if not registeredScreenSpaces[name] then
        logger.error(`Couldn't find space with name: {name}`)
    end

    return registeredScreenSpaces[name]
end
-- ScreenSpace -- end --

-- BillboardSpace -- start --
local registeredBillboardSpaces: {[string]: SpaceType.BillboardSpace} = {}
local defaultBillboardProperties = {
    name = "BillboardSpace",
    absoluteSize = Vector2.zero,
    absolutePosition = Vector2.zero,
    absoluteRotation = 0,
    visible = true,
    zIndexBehavior = Enum.ZIndexBehavior.Sibling,

    active = true,
    adornee = Undefined,
    alwaysOnTop = false,
    brightness = 1,
    clipsDescendants = true,
    currentDistance = 0,
    distanceStep = 0,
    extentsOffset = Vector3.zero,
    extentsOffsetWorldSpace = Vector3.zero,
    lightInfluence = 1,
    maxDistance = math.huge,
    playerToHideFrom = Undefined,
    size = Units.Size(200, 50),
    sizeOffset = Vector2.zero,
    studsOffset = Vector3.zero,
    studsOffsetWorldSpace = Vector3.zero
}

table.freeze(defaultBillboardProperties)

Space.createBillboardSpace = createConstructor(
    registeredBillboardSpaces,
    function(): LayerCollector
        return Instance.new("BillboardGui")
    end,
    {
        active = "Active",
        adornee = "Adornee",
        alwaysOnTop = "AlwaysOnTop",
        brightness = "Brightness",
        clipsDescendants = "ClipsDescendants",
        currentDistance = "CurrentDistance",
        distanceStep = "DistanceStep",
        extentsOffset = "ExtentsOffset",
        extentsOffsetWorldSpace = "ExtentsOffsetWorldSpace",
        lightInfluence = "LightInfluence",
        maxDistance = "MaxDistance",
        playerToHideFrom = "PlayerToHideFrom",
        size = "Size",
        sizeOffset = "SizeOffset",
        studsOffset = "StudsOffset",
        studsOffsetWorldSpace = "StudsOffsetWorldSpace"
    },
    defaultBillboardProperties,
    { -- transform
        size = Units.ToUDim2
    },
    { -- sync
        currentDistance = true
    },
    { -- readonly
        currentDistance = true
    }
) :: (name: string, props: TypeFuncs.Partial<SpaceType.SurfaceSpaceProps>?) -> SpaceType.SurfaceSpace

function Space.getBillboardSpace(name: string): SpaceType.BillboardSpace
    if not registeredBillboardSpaces[name] then
        logger.error(`Couldn't find space with name: {name}`)
    end

    return registeredBillboardSpaces[name]
end
-- BillboardSpace -- end --

-- SurfaceSpace -- start --
local registeredSurfaceSpaces: {[string]: SpaceType.SurfaceSpace} = {}
local defaultSurfaceProperties = {
    name = "SurfaceSpace",
    absoluteSize = Vector2.zero,
    absolutePosition = Vector2.zero,
    absoluteRotation = 0,
    visible = true,
    zIndexBehavior = Enum.ZIndexBehavior.Sibling,

    active = true,
    adornee = Undefined,
    face = Enum.NormalId.Front,
    alwaysOnTop = false,
    brightness = 1,
    canvasSize = Vector2.new(800, 600),
    clipsDescendants = true,
    lightInfluence = 1,
    maxDistance = 1000,
    pixelsPerStud = 50,
    sizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
    toolPunchThroughDistance = 0,
    zOffset = 0
}

table.freeze(defaultSurfaceProperties)

Space.createSurfaceSpace = createConstructor(
    registeredSurfaceSpaces,
    function(): LayerCollector
        return Instance.new("SurfaceGui")
    end,
    {
        active = "Active",
        adornee = "Adornee",
        face = "Face",
        alwaysOnTop = "AlwaysOnTop",
        brightness = "Brightness",
        canvasSize = "CanvasSize",
        clipsDescendants = "ClipsDescendants",
        lightInfluence = "LightInfluence",
        maxDistance = "MaxDistance",
        pixelsPerStud = "PixelsPerStud",
        sizingMode = "SizingMode",
        toolPunchThroughDistance = "ToolPunchThroughDistance",
        zOffset = "ZOffset"
    },
    defaultSurfaceProperties
) :: (name: string, props: TypeFuncs.Partial<SpaceType.SurfaceSpaceProps>?) -> SpaceType.SurfaceSpace

function Space.getSurfaceSpace(name: string): SpaceType.SurfaceSpace
    if not registeredSurfaceSpaces[name] then
        logger.error(`Couldn't find space with name: {name}`)
    end

    return registeredSurfaceSpaces[name]
end
-- BillboardSpace -- end --

-- StorySpace -- start --
local function findUIScale(target: GuiObject): UIScale?
    local current: Instance? = target

    while current do
        local uiScale = current:FindFirstChildOfClass("UIScale")

        if uiScale then
            return uiScale
        end

        current = current.Parent
    end

    return nil
end

local freezeAndClear = Helpers.freezeAndClear

--- Used for support of UI Labs stories
local function createStorySpace(target: Frame): WidgetType.SpaceLike
    local space = Widget.createEmptyWidget() :: any
    space._typeName = "storySpace"
    space._widgetLike = true
    space._isSpaceLike = true
    space._widgetName = "storySpace"
    space._features["children"] = true
    space._features["events"] = true

    local signals = Signals.new()
    local events = Events.new()
    local hooks = Hooks.new()

    space.signals = signals

    local isDestroyed = false

    local fire = events.fire
    local fireHook = hooks.fire

    local cleanups: {RBXScriptConnection | () -> ()} = {}
    local objectRef = Ref.new(target)

    -- box: main -- start --
    local function ensureNotDestroyed()
        if isDestroyed then
            logger.error("[%s %d] Tried to access widget after it was destroyed", space._widgetName, space._uniqueId)
        end
    end

    local isDestroying = false
    function space.destroy()
        if isDestroyed then return end
        if isDestroying then return end

        -- So if event calls .destroy() again
        isDestroying = true
        fire("Destroying")
        isDestroyed = true

        for _, cleanup in ipairs(cleanups) do
            if typeof(cleanup) == "RBXScriptConnection" then
                cleanup:Disconnect()
            else
                cleanup()
            end
        end

        freezeAndClear(cleanups)

        objectRef.destroy()

        fire("Destroyed")
        events.destroy()
        hooks.clear()

        State.removeWidget(space :: any)
    end

    function space.isDestroyed()
        return isDestroyed
    end

    function space._addCleanup(toCleanup: RBXScriptConnection | () -> ())
        ensureNotDestroyed()
        table.insert(cleanups, toCleanup)
    end
    -- box: main -- end --

    -- feature: events -- start --
    local function listen(name: string, callback: (...any) -> ...boolean?): () -> ()
        ensureNotDestroyed()
        return events.listen(name, callback)
    end
    space.listen = listen

    function space._linkEvent(...)
        logger.error("Story space cannot link events")
    end
    -- feature: events -- end --

    -- widget: object -- start --
    function space.getObject()
        return target
    end

    function space.getObjectRef()
        return Ref.makeProtected(objectRef :: any)
    end

    function space._redraw()
        for _, child in space.children do
            if not child.isImplemented("_redraw") then
                continue
            end

            child._redraw()
        end
    end

    function space._createObject()
        fireHook("ObjectCreateScheduled")
        return nil
    end
    -- widget: object -- end --

    -- features: all -- start --
    Children(
        space,
        ensureNotDestroyed,
        hooks,
        events
    )
    -- features: all -- end --

    local uiScale = findUIScale(target)
    local function scaleFunction(value: number, getOriginal: boolean?): number
        if not uiScale then
            return value
        end

        if not getOriginal then
            return value
        else
            return value / uiScale.Scale
        end
    end

    if uiScale then
        uiScale:GetPropertyChangedSignal("Scale"):Connect(function(...)
            signals.fire("ScaleChanged")
        end)
    end

    function space.scaleObject(obj: any, getOriginal: boolean?): any
        if typeof(obj) == "table" then
            local fn = scaleFunctions[(obj :: any)._typeName or ""]

            if not fn then
                return obj
            else
                return fn(scaleFunction, obj, getOriginal)
            end
        else
            local fn = scaleFunctions[typeof(obj)]

            if not fn then
                return obj
            else
                return fn(scaleFunction, obj, getOriginal)
            end
        end
    end

    function space.changeScaleFn(...: any)
        logger.error("Story space doesn't support changing scale function")
    end

    return space
end
Space.createStorySpace = createStorySpace
-- StorySpace -- end --

return table.freeze(Space)