--!strict
--!optimize 2

const AnimationsType = require(script.Parent.Parent.Types.Animations)
const Modifier = require(script.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Types.Utils)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Events = require(script.Parent.Parent.Utils.Events)
const Widget = require(script.Parent.Parent.Types.Widget)
const State = require(script.Parent.Parent.State)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Hooks = require(script.Parent.Parent.Utils.Hooks)
const Units = require(script.Parent.Parent.Utils.Units)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Scheduler = require(script.Parent.Parent.Utils.Scheduler)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Animations = require(script.Parent.WidgetFeatures.Animations)

const Children = require(script.Parent.WidgetFeatures.Children)
const Modifiers = require(script.Parent.WidgetFeatures.Modifiers)
const Parenting = require(script.Parent.WidgetFeatures.Parenting)
const Properties = require(script.Parent.WidgetFeatures.Properties)
const Transitions = require(script.Parent.WidgetFeatures.Transitions)

const logger = Logging.getLogger("PeanutUI.Classes.Widget")

local counter = 1
local WidgetClass = {}

local unsupportedList = table.freeze({})
local function unsupportedFn(...: never): ...never
    logger.error("Looks like this class didn't implement this function")
end

WidgetClass.unsupportedFn = unsupportedFn :: (...never) -> ...never
WidgetClass.unsupportedList = unsupportedList

local defaultWidget = {
    _typeName = "unknownWidget",
    _widgetLike = true,
    _widgetName = "widget",
    _uniqueId = -1,
    _features = {
        properties = false,
        transitions = false,
        events = false,
        parenting = false,
        children = false,
        modifiers = false
    },

    destroy = unsupportedFn,
    isDestroyed = unsupportedFn,

    setAnimation = unsupportedFn,
    getAnimation = unsupportedFn,

    setModifier = unsupportedFn,
    getModifier = unsupportedFn,
    getRef = unsupportedFn,

    setProperty = unsupportedFn,
    snapProperty = unsupportedFn,
    setTransition = unsupportedFn,
    getProperty = unsupportedFn,
    observe = unsupportedFn,
    listen = unsupportedFn,

    setParent = unsupportedFn,
    getParent = unsupportedFn,
    getSpace = unsupportedFn,

    addChild = unsupportedFn,
    removeChild = unsupportedFn,
    clearChildren = unsupportedFn,
    children = unsupportedList,

    _setCreateObject = unsupportedFn,
    _linkProperty = unsupportedFn,
    _linkEvent = unsupportedFn,
    _setParent = unsupportedFn,
    _createObject = unsupportedFn,
    _redraw = unsupportedFn,
    _addCleanup = unsupportedFn,
    _propertiesRefs = unsupportedList,
    _setObject = unsupportedFn,
    _setSpace = unsupportedFn,

    getObject = unsupportedFn,
    getObjectRef = unsupportedFn,
    isImplemented = function(...)
        return false
    end
}
table.freeze(defaultWidget)

local defaultProperties: Widget.DefaultProperties = {
    visible = true,
    zIndex = 0,
    clipsDescendants = false,
    backgroundColor = Color3.new(1, 1, 1),
    backgroundTransparency = 0,
    size = Units.Size(),
    position = Units.Position(),
    anchorPoint = Vector2.new(0, 0),
    layoutOrder = 0,
    autoLayoutOrder = 0,
    rotation = 0,

    sizeConstraint = Enum.SizeConstraint.RelativeXY,
    automaticSize = Enum.AutomaticSize.None,

    selectable = false,
    selectionOrder = 0,

    interactable = true,
    active = false,

    absolutePosition = Vector2.zero,
    absoluteSize = Vector2.zero,
    absoluteRotation = 0,

    inputSink = Enum.InputSink.None,

    borderColor = Color3.new(0, 0, 0),
    borderMode = Enum.BorderMode.Outline,
    borderSizePx = 0,

    name = "Widget"
}

table.freeze(defaultProperties)

local function defaultSetup(widget: Widget.BaseInterface)
    if widget.isImplemented("properties", true) then
        local link = widget._linkProperty
        local observe = widget.observe
        local setProperty = widget.setProperty
        local propertiesRefs = widget._propertiesRefs

        for key, value in pairs(defaultProperties) do
            if propertiesRefs[key] and propertiesRefs[key].getValue() ~= nil then
                continue
            end

            setProperty(key, value)
        end

        link("name", "Name")
        link("visible", "Visible")
        link("layoutOrder", "LayoutOrder")
        link("zIndex", "ZIndex")
        link("clipsDescendants", "ClipsDescendants")
        link("rotation", "Rotation")
        link("size", "Size", function(value)
            local space = widget.getSpace()
            if not space then
                return Units.ToUDim2(value)
            end

            return space.scaleObject(Units.ToUDim2(value))
        end, nil, nil, {"ScaleChanged"})
        link("position", "Position", function(value)
            local space = widget.getSpace()
            if not space then
                return Units.ToUDim2(value)
            end

            return space.scaleObject(Units.ToUDim2(value))
        end, nil, nil, {"ScaleChanged"})
        link("anchorPoint", "AnchorPoint")
        link("backgroundColor", "BackgroundColor3")
        link("backgroundTransparency", "BackgroundTransparency")

        link("automaticSize", "AutomaticSize")
        link("sizeConstraint", "SizeConstraint")

        link("selectable", "Selectable")
        link("selectionOrder", "SelectionOrder")
        link("selectionImageObject", "SelectionImageObject")
        link("nextSelectionDown", "NextSelectionDown")
        link("nextSelectionUp", "NextSelectionUp")
        link("nextSelectionRight", "NextSelectionRight")
        link("nextSelectionLeft", "NextSelectionLeft")

        link("inputSink", "InputSink")
        link("borderColor", "BorderColor3")
        link("borderMode", "BorderMode")
        link("borderSizePx", "BorderSizePixel", function(v)
            local space = widget.getSpace()
            if not space then
                return v
            end

            return space.scaleObject(v, true)
        end, nil, nil, {"ScaleChanged"})

        link("interactable", "Interactable")
        link("active", "Active")

        link("absoluteSize", "AbsoluteSize", nil, function(v)
            local space = widget.getSpace()
            if not space then
                return v
            end

            return space.scaleObject(v, true)
        end, true, {"ScaleChanged"})
        link("absolutePosition", "AbsolutePosition", nil, function(v)
            local space = widget.getSpace()
            if not space then
                return v
            end

            return space.scaleObject(v, true)
        end, true, {"ScaleChanged"})
        link("absoluteRotation", "AbsoluteRotation", nil, nil, true)

        setProperty("layoutOrder", widget._propertiesRefs.autoLayoutOrder or 0)

        observe("visible", function(newValue: boolean)
            if not widget.getObject() and newValue then
                widget._createObject()
            end

            return nil
        end)
    end

    if widget.isImplemented("_linkEvent") then
        local linkEvent = widget._linkEvent
        linkEvent("InputBegan")
        linkEvent("InputChanged")
        linkEvent("InputEnded")

        linkEvent("MouseEnter")
        linkEvent("MouseMoved")
        linkEvent("MouseLeave")

        linkEvent("MouseWheelBackward")
        linkEvent("MouseWheelForward")

        linkEvent("SelectionChanged")
        linkEvent("SelectionGained")
        linkEvent("SelectionLost")

        linkEvent("TouchLongPress")
        linkEvent("TouchPan")
        linkEvent("TouchPinch")
        linkEvent("TouchTap")
    end
end

local function createEmptyWidget(): Widget.BaseInterface
    counter += 1
    local id = counter

    local newWidget = table.clone(defaultWidget) :: any
    newWidget._uniqueId = id

    function newWidget.isImplemented(field: string, isFeature: boolean?): boolean
        if isFeature == true then
            if not newWidget._features then
                return false
            end

            return newWidget._features[field]
        end
        return (
            newWidget[field] ~= nil
            and newWidget[field] ~= unsupportedFn
            and newWidget[field] ~= unsupportedList
        )
    end

    State.addWidget(newWidget :: any)

    return newWidget
end

WidgetClass.createEmptyWidget = createEmptyWidget

local isWidget = Helpers.isWidget
local widgetsAreSame = Helpers.widgetsAreSame
local freezeAndClear = Helpers.freezeAndClear

WidgetClass.isWidget = isWidget
WidgetClass.widgetsAreSame = widgetsAreSame

function WidgetClass.getNewId(): number
    counter += 1
    return counter
end

-- Inspired by Rust
function WidgetClass.tryInto(obj: any): Widget.Interface?
    if isWidget(obj) then
        return obj
    end

    return nil
end

function WidgetClass.into(obj: any): Widget.Interface
    if isWidget(obj) then
        return obj
    end

    logger.error("Object was not a widget")
    error("")
end

function WidgetClass.new<C>(
    args: Widget.Args?,
    disableFeatures: {[string]: boolean}?
): Widget.Interface
    local instance = createEmptyWidget() :: typeof({})
    local id = instance._uniqueId

    local isDestroyed = false
    logger.debug("New widget with id %d created", id)

    local hooks = Hooks.new()

    local object: Instance? = nil
    local objectRef: Utils.Ref<Instance?> = Ref.new(nil) :: any
    local cleanups: { RBXScriptConnection | () -> () } = {}

    local linkedEvents: {[string]: string} = {}
    local linkedEventListener: {[string]: RBXScriptConnection} = {}

    local events = Events.new()
    local fire = events.fire
    local fireHook = hooks.fire

    instance._typeName = "widget"
    instance._widgetName = args and args.widgetName or "widget"
    instance._uniqueId = id

    local features = {
        events = true,

        properties = true,
        transitions = true,
        parenting = true,
        children = true,
        modifiers = true,
        animations = true
    }

    if disableFeatures then
        for key, value in disableFeatures do
            if value == true then
                if key == "events" then
                    logger.warn("Feature %s cannot be disabled, make your own widget-like class", key)
                    continue
                end

                features[key] = false
            end
        end
    end

    instance._features = features

    local function setObject(newObject: Instance?)
        object = newObject
        objectRef.setValue(newObject)
    end

    -- widget: main -- start --
    local function ensureNotDestroyed()
        if isDestroyed then
            logger.error("[%s %d] Tried to access widget after it was destroyed", instance._widgetName, instance._uniqueId)
        end
    end

    local isDestroying = false
    function instance.destroy()
        if isDestroyed then return end
        if isDestroying then return end

        -- So if event calls .destroy() again
        isDestroying = true
        logger.debug("[%s %d] destroying", instance._widgetName, id)
        fire("Destroying")
        isDestroyed = true

        logger.debug("[%s %d] cleaning up", instance._widgetName, id)
        for _, cleanup in ipairs(cleanups) do
            if typeof(cleanup) == "RBXScriptConnection" then
                cleanup:Disconnect()
            else
                cleanup()
            end
        end

        logger.debug("[%s %d] disconnecting linked events", instance._widgetName, id)
        for key, signal in pairs(linkedEventListener) do
            signal:Disconnect()
        end

        if object then
            logger.debug("[%s %d] destroying object", instance._widgetName, id)
            fire("ObjectDestroying", object)
            object:Destroy()
            setObject(nil)
            objectRef.destroy()
        end

        freezeAndClear(linkedEvents)
        freezeAndClear(linkedEventListener)
        freezeAndClear(cleanups)

        logger.debug("[%s %d] destroyed", instance._widgetName, id)
        fire("Destroyed", object)
        hooks.clear()
        events.destroy()
        State.removeWidget(instance :: any)
        table.freeze(instance)
    end

    function instance.isDestroyed()
        return isDestroyed
    end

    function instance._addCleanup(obj: RBXScriptConnection | () -> ())
        ensureNotDestroyed()
        table.insert(cleanups, obj)
    end
    -- widget: main -- end --

    -- feature: events -- start --
    local function checkLinkedEvent(name: string)
        local event = linkedEvents[name]

        if not event then
            return
        end

        if object and events.listeners[name] and not linkedEventListener[name] then
            local instanceEvent = (object :: any)[event]
            if typeof(instanceEvent) == "RBXScriptSignal" then
                local conn = (instanceEvent :: RBXScriptSignal):Connect(function(...)
                    fire(name, ...)
                end)
                linkedEventListener[name] = conn
            end
        end
    end

    local function listen(name: string, callback: (...any) -> ...boolean?): () -> ()
        ensureNotDestroyed()
        local unlisten = events.listen(name, callback)
        checkLinkedEvent(name)
        return unlisten
    end
    instance.listen = listen

    local function linkEvent(name: string, event: string?)
        event = Helpers.removeUndefined(event) or name

        linkedEvents[name] = event
        checkLinkedEvent(name)
    end
    instance._linkEvent = linkEvent
    -- feature: events -- end --

    -- widget: object -- start --
    function instance.getObject(): Instance?
        return object
    end

    function instance.getObjectRef(): Utils.ProtectedRef<Instance?>
        return Ref.makeProtected(objectRef :: any)
    end

    local function redrawNow()
        ensureNotDestroyed()

        if object then
            logger.debug("[%s %d] redraw was called", instance._widgetName, id)

            fireHook("BeforeRedraw", object)
            fireHook("OnRedraw", object)
            fireHook("AfterRedraw", object)
        end
    end

    local redrawScheduled = false
    local function redraw()
        if redrawScheduled then return end
        redrawScheduled = true

        Scheduler.schedule("redraw", function(...)
            redrawScheduled = false
            if isDestroyed then return end

            redrawNow()
        end)
    end
    instance._redraw = redraw

    local createObjectFn = nil :: (() -> Instance)?

    function instance._setObject(new: any)
        if instance._typeName == "widget" then
            logger.error("Function _setObject can be called only on custom widget-like type!")
        end

        setObject(new)
    end

    function instance._setCreateObject(fn: () -> Object?)
        createObjectFn = fn
    end

    local objectCreationScheduled = false
    function instance._createObject()
        ensureNotDestroyed()
        if object then
            return
        end

        logger.debug("[%s %d] _createObject is called", instance._widgetName, id)

        if features.properties then
            local isVisible = (instance :: Widget.BaseInterface).getProperty("visible")
            if not isVisible then
                logger.debug("[%s %d] Skipped creating cause widget is invisible", instance._widgetName, id)
                return
            end
        end

        if objectCreationScheduled then return end
        objectCreationScheduled = true

        Scheduler.schedule("create", function(...)
            if isDestroyed then return end
            if not createObjectFn then
                logger.debug("[%s %d] _createObject skipped (no create function)", instance._widgetName, id)
                objectCreationScheduled = false
                return
            end

            if features.parenting then
                local parent = (instance :: Widget.BaseInterface).getParent()
                if not parent or not parent.getObject() then
                    logger.debug("[%s %d] Skipped creating cause there's nothing to attach", instance._widgetName, id)
                    objectCreationScheduled = false
                    return
                end
            end
            fire("BeforeObjectCreated")

            logger.debug("[%s %d] _createObject is creating new object", instance._widgetName, id)
            local newObject = createObjectFn()
            newObject:SetAttribute("_uniqueId", id)

            setObject(newObject)
            objectCreationScheduled = false

            if features.parenting then
                local parent = (instance :: Widget.Interface).getParent()

                if newObject and parent and parent.getObject() then
                    newObject.Parent = parent.getObject()
                end
            end

            for name, _ in pairs(linkedEvents) do
                checkLinkedEvent(name)
            end

            fire("ObjectCreated", newObject)
            fireHook("ObjectCreated", newObject)
            logger.debug("[%s %d] _createObject created object", instance._widgetName, id)

            redraw()
        end)

        fireHook("ObjectCreateScheduled")
    end
    -- widget: object -- end --

    -- widget: animated properties -- start --
    local transitions: {[string]: AnimationsType.Transition}? = nil
    local animatedProperty: {[string]: string}? = nil
    local ensureRef: ((string) -> Utils.Ref<any>)? = nil

    if features.transitions or features.animations then
        animatedProperty = {}
    end

    if features.transitions then
        transitions = {}
    end

    events.listen("Destroyed", function()
        if transitions then
            freezeAndClear(transitions)
        end
        if animatedProperty then
            freezeAndClear(animatedProperty)
        end
    end)
    -- widget: animated properties -- end --

    -- feature: property -- start --
    local linkedProperties: {[string]: string}? = nil
    local linkedPropertiesMap: {[string]: string}? = nil

    if features.properties then
        linkedProperties, linkedPropertiesMap, _, _, ensureRef = Properties(
            instance,
            ensureNotDestroyed,
            transitions,
            cleanups,
            hooks,
            events,
            args and args.properties :: {[string]: any}
        )
    end
    -- feature: property -- end --

    -- feature: modifiers -- start --
    local modifierComponents: {[string]: Modifier.Component}
    if features.modifiers then
        modifierComponents = Modifiers(
            instance,
            ensureNotDestroyed,
            hooks,
            args and args.modifiers
        )
    end
    -- feature: children -- end --

    -- feature: children -- start --
    local children: {Widget.InternalInterface}? = nil
    if features.children then
        children = Children(
            instance,
            ensureNotDestroyed,
            hooks,
            events
        )
    end
    -- feature: children -- end --

    -- feature: parenting -- start --
    if features.parenting then
        Parenting(
            instance,
            ensureNotDestroyed,
            children,
            modifierComponents,
            events,
            hooks
        )
    end
    -- feature: parenting -- end --

    -- feature: transitions -- start --
    if features.transitions then
        Transitions(
            instance,
            ensureNotDestroyed,
            hooks,
            transitions,
            animatedProperty,
            linkedProperties,
            args and args.transitions
        )
    end
    -- feature: transitions -- end --

    -- feature: animations -- start --
    if features.animations then
        Animations(
            instance,
            ensureNotDestroyed,
            hooks,
            animatedProperty,
            linkedProperties,
            linkedPropertiesMap,
            ensureRef,
            args and args.animations
        )
    end
    -- feature: animations -- end --

    local setupOverride = args and args.defaultSetupOverride
    if setupOverride == Undefined then
        -- Nothing
    elseif setupOverride then
        (setupOverride :: any)(instance :: any, defaultSetup :: any)
    else
        defaultSetup(instance :: any)
    end

    fireHook("OnSetup")

    if args then
        if args.events then
            for key, callback in pairs(args.events :: {[string]: any}) do
                listen(key, callback)
            end
        end

        if features.children and args.children then
            for _, child in ipairs(args.children) do
                (instance :: Widget.BaseInterface).addChild(child)
            end
        end

        if args.onSetup then
            args.onSetup(instance :: any)
        end
    end

    if isDestroyed then
        logger.critical("Widget was destroyed on setup")
    end

    -- Dropping reference
    args = nil

    return instance :: any
end

return table.freeze(WidgetClass)