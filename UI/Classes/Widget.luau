--!strict
--!optimize 2

const Modifiers = require(script.Parent.Modifiers)
const Animations = require(script.Parent.Parent.Types.Animations)
const Modifier = require(script.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Types.Utils)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Events = require(script.Parent.Parent.Utils.Events)
const Widget = require(script.Parent.Parent.Types.Widget)
const State = require(script.Parent.Parent.State)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Units = require(script.Parent.Parent.Utils.Units)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Scheduler = require(script.Parent.Parent.Utils.Scheduler)
const Undefined = require(script.Parent.Parent.Utils.Undefined)

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

    selectable = true,
    selectionOrder = 0,

    interactable = true,
    active = true,

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
    local link = widget._linkProperty
    local linkEvent = widget._linkEvent
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
            return value
        end

        return space.scaleObject(Units.ToUDim2(value))
    end)
    link("position", "Position", function(value)
        local space = widget.getSpace()
        if not space then
            return value
        end

        return space.scaleObject(Units.ToUDim2(value))
    end)
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
    end)

    link("interactable", "Interactable")
    link("active", "Active")

    link("absoluteSize", "AbsoluteSize", nil, function(v)
        local space = widget.getSpace()
        if not space then
            return v
        end

        return space.scaleObject(v, true)
    end, true)
    link("absolutePosition", "AbsolutePosition", nil, function(v)
        local space = widget.getSpace()
        if not space then
            return v
        end

        return space.scaleObject(v, true)
    end, true)
    link("absoluteRotation", "AbsoluteRotation", nil, nil, true)

    setProperty("layoutOrder", widget._propertiesRefs.autoLayoutOrder)

    observe("visible", function(newValue: boolean)
        if not widget.getObject() and newValue then
            widget._createObject()
        end

        return nil
    end)

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

local function isWidget(obj: any)
    if typeof(obj) ~= "table" then
        return false
    end

    if obj._widgetLike == true then
        return true
    end

    if not obj._typeName or obj._typeName ~= "widget" then
        return false
    end

    return true
end

local function widgetsAreSame(a: any, b: any)
    if not isWidget(a) or not isWidget(b) then
        return false
    end

    return a._uniqueId == b._uniqueId
end

local function readonly<T>(original: T): T
	local proxy = {}

	setmetatable(proxy, {
		__index = original,

		__newindex = function()
			error("attempt to modify read-only table", 2)
		end,

        __iter = function()
            return next, original, nil
        end,

		__metatable = false,
	})

	return proxy :: T
end

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

    local nextLayoutOrder = 1

    local space: Widget.SpaceLike? = nil

    local propertiesRefs: {[string]: Utils.Ref<any>} = {}
    local object: Instance? = nil
    local objectRef: Utils.Ref<Instance?> = Ref.new(nil) :: any
    local cleanups: { RBXScriptConnection | () -> () } = {}
    local parent: Widget.Interface? = nil

    -- Key is property
    local transitions: {[string]: Animations.Transition} = {}

    local animatedProperty: {[string]: string} = {}

    local linkedProperties: {[string]: string} = {}
    local linkedPropertiesUpdate: {[string]: (value: any) -> ()} = {}
    local linkedPropertiesMap: {[string]: string} = {}

    local animations: {[string]: Animations.Animation} = {}
    local propertyToAnimation: {[string]: Animations.Animation} = {}

    local readonlyProperties: {[string]: boolean} = {}

    local rbxLinkedProperties: {[string]: string} = {}
    local rbxPropertyEvent: {[string]: RBXScriptConnection} = {}
    local rbxPropertyLocked: {[string]: boolean} = {}
    local rbxPropertyWatching: {[string]: number} = {}
    local rbxPropertyTransform: {[string]: (any) -> any} = {}

    local modifierComponents: {[string]: Modifier.Component} = {}

    local linkedEvents: {[string]: string} = {}
    local linkedEventListener: {[string]: RBXScriptConnection} = {}

    local events = Events.new()
    local children: {Widget.InternalInterface} = {}
    local childrenIndex: {[Widget.InternalInterface]: number} = {}

    -- So redraw doesn't start any transitions
    local inRedrawMode = false

    instance._typeName = "widget"
    instance._widgetName = args and args.widgetName or "widget"
    instance._uniqueId = id
    instance._propertiesRefs = propertiesRefs
    instance.children = readonly(children)

    local features = {
        properties = true,
        transitions = true,
        events = true,
        parenting = true,
        children = true,
        modifiers = true,
        animations = true
    }

    if disableFeatures then
        for key, value in disableFeatures do
            if value == true then
                if key == "properties" or key == "events" then
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
            logger.error("Tried to access widget after it was destroyed")
        end
    end

    local function freezeAndClear(tbl: {[any]: any}?)
        if type(tbl) ~= "table" then
            return
        end

        table.clear(tbl)
        table.freeze(tbl)
    end

    local isDestroying = false
    function instance.destroy()
        if isDestroyed then return end
        if isDestroying then return end

        -- So if event calls .destroy() again
        isDestroying = true
        events.fire("Destroying")
        isDestroyed = true

        if parent then
            parent.removeChild(instance :: any)
        end

        for _, cleanup in ipairs(cleanups) do
            if typeof(cleanup) == "RBXScriptConnection" then
                cleanup:Disconnect()
            else
                cleanup()
            end
        end

        for key, signal in pairs(linkedEventListener) do
            signal:Disconnect()
        end

        for key, signal in pairs(rbxPropertyEvent) do
            signal:Disconnect()
        end

        for _, ref in pairs(propertiesRefs) do
            ref.destroy()
        end

        local currentChildren = table.clone(children)

        for _, child in ipairs(currentChildren :: any) do
            child._setParent(nil)
            child.destroy()
        end

        if object then
            for _, transition in pairs(transitions) do
                transition.stop(object)
            end
        end

        if object then
            events.fire("ObjectDestroying", object)
            object:Destroy()
            setObject(nil)
        end

        freezeAndClear(propertiesRefs)
        freezeAndClear(transitions)
        freezeAndClear(animatedProperty)
        freezeAndClear(linkedProperties)
        freezeAndClear(linkedPropertiesUpdate)
        freezeAndClear(linkedPropertiesMap)
        freezeAndClear(animations)
        freezeAndClear(propertyToAnimation)
        freezeAndClear(readonlyProperties)
        freezeAndClear(rbxLinkedProperties)
        freezeAndClear(rbxPropertyEvent)
        freezeAndClear(rbxPropertyLocked)
        freezeAndClear(rbxPropertyWatching)
        freezeAndClear(rbxPropertyTransform)
        freezeAndClear(modifierComponents)
        freezeAndClear(linkedEvents)
        freezeAndClear(linkedEventListener)
        freezeAndClear(children)
        freezeAndClear(childrenIndex)
        freezeAndClear(cleanups)

        events.fire("Destroyed", object)
        events.destroy()
        State.removeWidget(instance :: any)
        table.freeze(instance)
    end

    function instance.isDestroyed()
        return isDestroyed
    end

    function instance._addCleanup(obj: RBXScriptConnection | () -> ())
        table.insert(cleanups, obj)
    end

    local function ensureRef(key: string)
        local ref = propertiesRefs[key]

        if not ref then
            propertiesRefs[key] = Ref.new(nil)
            ref = propertiesRefs[key]
        end

        return ref
    end
    -- widget: main -- end --

    -- feature: property -- start --
    local function setProperty(key: string, value: any | Utils.Ref<any>)
        local ref = ensureRef(key)

        value = Helpers.removeUndefined(value)

        if readonlyProperties[key] == true then
            logger.error("Cannot set readonly property")
        end

        if typeof(value) == "table" and value._typeName ~= "ref" then
            value = Ref.reactive(value)
        end

        ref.setValue(value)
        events.fire("PropertyChanged", key, ref.getValue())
    end

    function instance.setProperty(key: string, value: any | Utils.Ref<any>)
        ensureNotDestroyed()

        setProperty(key, value)
    end

    local function link(
        name: string,
        property: string,
        transformFn: ((any) -> any)?,
        syncWithObject: (boolean | (any) -> any)?,
        readonly: boolean?
    )
        ensureNotDestroyed()
        if linkedProperties[name] then
            logger.error("Cannot link property that is already linked")
        end

        logger.debug(
            "[%s %d] Linking property. Name %s, Property %s, Transform %s, Sync %s, Readonly %s",
            instance._widgetName, id, name, property, typeof(transformFn), typeof(syncWithObject),
            tostring(readonly or false)
        )

        if
            readonly ~= true
            and syncWithObject ~= nil
            and transformFn ~= nil
            and typeof(syncWithObject) ~= "function"
        then
            logger.error("If you sync with GuiObject you have to provide zero or two transform functions e.g. link(name, property, fn1, fn2) or link(name, property, nil, true)")
        end

        if typeof(syncWithObject) == "function" then
            rbxPropertyTransform[name] = syncWithObject
        end

        linkedProperties[name] = property
        linkedPropertiesMap[property] = name

        local ref = ensureRef(name)

        if syncWithObject then
            rbxLinkedProperties[name] = property
        end

        if readonly == true then
            readonlyProperties[name] = true
            return
        end

        local function update(value)
            if rbxPropertyLocked[name] == true then
                logger.debug("[%s %d] Skipped update of %s cause it's locked", instance._widgetName, id, name)
                return
            end

            if object then
                if value == Undefined then
                    value = nil
                end

                if transformFn then
                    value = transformFn(value)
                end

                local oldValue = (object :: any)[property]
                if oldValue == nil or value == oldValue then
                    return
                end

                logger.debug(
                    "[%s %d] Updating property %s to %s (type %s)",
                    instance._widgetName, id, name, tostring(value), typeof(value)
                )
                if transitions[name] and not inRedrawMode then
                    transitions[name].animate(object, property, value)
                else
                    (object :: any)[property] = value
                end
            end
        end

        linkedPropertiesUpdate[name] = update
        table.insert(cleanups, (ref.watch(update)))
    end
    instance._linkProperty = link

    local function syncRbxProperty(key: string)
        if not object then
            return
        end

        local rbxKey = rbxLinkedProperties[key]
        if not rbxKey then
            return
        end

        local ref = ensureRef(key)

        rbxPropertyLocked[key] = true
        local value = (object :: any)[rbxKey]

        local transformFn = rbxPropertyTransform[key]
        if transformFn then
            value = transformFn(value)
        end

        ref.setValue(value)
        events.fire("PropertyChanged", key, value)

        rbxPropertyLocked[key] = nil
    end

    local function getProperty(key: any): any
        ensureNotDestroyed()
        local ref = propertiesRefs[key]
        if not ref then
            local rbxKey = rbxLinkedProperties[key]
            if object and rbxKey then
                return (object :: any)[rbxKey]
            end

            return nil
        else
            if rbxLinkedProperties[key] then
                syncRbxProperty(key)
            end

            local value = ref.getValue()
            value = Helpers.removeUndefined(value)

            return value
        end
    end
    instance.getProperty = getProperty

    local function checkRbxPropertyEvent(key: string)
        if not object then
            return
        end

        local rbxKey = rbxLinkedProperties[key]
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
            rbxPropertyEvent[key] = object:GetPropertyChangedSignal(rbxLinkedProperties[key]):Connect(function(value)
                if object and transitions[key] and transitions[key].isRunning(object, rbxKey) then
                    return
                end
                syncRbxProperty(key)
            end)
        end
    end

    local function observe(key: string, callback: (newValue: any) -> ...boolean?): () -> ()
        ensureNotDestroyed()

        local ref = ensureRef(key)

        if rbxLinkedProperties[key] then
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

            if rbxLinkedProperties[key] then
                local counter = rbxPropertyWatching[key] or 0
                rbxPropertyWatching[key] = counter - 1

                checkRbxPropertyEvent(key)
            end
        end

        ref.setOnUnwatch(id, onUnwatch)

        return unwatch
    end
    instance.observe = observe

    function instance.getRef(key: string): Utils.ProtectedRef<any>
        ensureNotDestroyed()

        local ref = ensureRef(key)

        local onWatch: () -> ()? = nil
        local onUnwatch: () -> ()? = nil
        if rbxLinkedProperties[key] then
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
    -- feature: property -- end --

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
                    events.fire(name, ...)
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

    function instance.getObjectRef(): Instance?
        return object
    end

    local function redrawNow()
        ensureNotDestroyed()

        inRedrawMode = true
        logger.debug("[%s %d] redraw was called", instance._widgetName, id)
    
        if parent and parent.getObject() then
            if object then
                object.Parent = parent.getObject()
            else
                instance._createObject()
            end
        end

        if object then
            for key, _ in pairs(rbxLinkedProperties) do
                syncRbxProperty(key)
            end

            for key, update in pairs(linkedPropertiesUpdate) do
                local ref = ensureRef(key)
                update(ref.getValue())
            end

            for _, modifier in pairs(modifierComponents) do
                modifier._redraw()
            end

            for _, animation in pairs(animations) do
                animation.animate(object)
            end
        end

        inRedrawMode = false
    end

    local redrawScheduled = false
    local function redraw()
        if redrawScheduled then return end
        redrawScheduled = true

        Scheduler.schedule("redraw", function(...)
            redrawScheduled = false
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

        if not getProperty("visible") or not parent then
            logger.debug("[%s %d] _createObject skipped (not visible)", instance._widgetName, id)
            -- Not creating object when it's not needed
            return
        end

        if objectCreationScheduled then return end
        objectCreationScheduled = true

        Scheduler.schedule("createObject", function(...)
            if not createObjectFn then
                logger.debug("[%s %d] _createObject skipped (no create function)", instance._widgetName, id)
                return
            end

            if not getProperty("visible") or not parent or not parent.getObject() then
                logger.debug("[%s %d] _createObject skipped (not visible)", instance._widgetName, id)
                -- Not creating object when it's not needed
                return
            end

            logger.debug("[%s %d] _createObject is creating new object", instance._widgetName, id)
            local newObject = createObjectFn()
            setObject(newObject)
            objectCreationScheduled = false

            if newObject and parent and parent.getObject() then
                newObject.Parent = parent.getObject()
                newObject:SetAttribute("_uniqueId", id)
            end

            for name, _ in pairs(linkedEvents) do
                checkLinkedEvent(name)
            end

            for key, _ in pairs(rbxPropertyWatching) do
                checkRbxPropertyEvent(key)
            end

            for _, modifier in pairs(modifierComponents) do
                modifier.mountTo(newObject)
            end

            events.fire("ObjectCreated", newObject)
            logger.debug("[%s %d] _createObject created object", instance._widgetName, id)

            redraw()
        end)

        for _, child in ipairs(children :: any) do
            child._createObject()
        end
    end
    -- widget: object -- end --

    -- feature: all -- start --
    if features.parenting then
        function instance.setParent(newParent: Widget.Interface?)
            ensureNotDestroyed()

            if newParent and not isWidget(newParent) then
                logger.error("Argument must be widget!")
            end

            if widgetsAreSame(newParent, instance) then
                logger.error("I can't be parent of myself!")
            end

            if newParent and parent and widgetsAreSame(parent, newParent) then
                return
            end

            if parent then
                parent.removeChild(instance :: any)
            end

            if newParent then
                newParent.addChild(instance :: any)
            end
        end

        function instance.getSpace()
            return space
        end

        function instance._setSpace(newSpace: Widget.SpaceLike?)
            space = newSpace

            for _, child in children do
                if child.isImplemented("_setSpace") then
                    child._setSpace(newSpace)
                end
            end

            for _, modifier in modifierComponents do
                modifier.setScaleObjectFn(newSpace and newSpace.scaleObject)
            end

            redraw()
        end

        function instance._setParent(newParent: Widget.Interface?)
            ensureNotDestroyed()

            parent = newParent

            if parent and parent._typeName == "space" then
                instance._setSpace(parent :: any)
            elseif parent and parent.isImplemented("getSpace") then
                local parentSpace = parent.getSpace()
                instance._setSpace(parentSpace)
            elseif space ~= nil then
                instance._setSpace(nil)
            end

            if parent and parent.getObject() and object then
                object.Parent = parent.getObject()
            elseif not parent and object then
                object.Parent = nil
            end

            events.fire("ParentChanged", newParent)
        end

        function instance.getParent()
            return parent
        end
    end

    if features.children then
        function instance.addChild(child: Widget.InternalInterface)
            ensureNotDestroyed()

            if not isWidget(child) then
                logger.error("Cannot add child that is not Widget!")
            end

            if child.getParent() then
                logger.error("Child already had parent!")
            end

            if not child.isImplemented("parenting", true) then
                logger.error("Child doesn't support parenting")
            end

            if widgetsAreSame(child, instance) then
                logger.error("I can't be parent of myself!")
            end
            logger.debug("[%s %d] Adding child: %s %d", instance._widgetName, id, child._widgetName, child._uniqueId)

            if child.isImplemented("properties", true) then
                -- Yummy auto order
                local currentOrder = child.getProperty("layoutOrder")
                if not currentOrder or currentOrder == 0 then
                    child.setProperty("layoutOrder", nextLayoutOrder)
                    nextLayoutOrder += 1
                end
            end

            child._setParent(instance :: any)

            table.insert(children, child)
            childrenIndex[child] = #children

            if object and child.isImplemented("_createObject") then
                child._createObject()
            end

            events.fire("ChildAdded", child)
        end

        function instance.removeChild(child: Widget.InternalInterface, andDestroy: boolean?)
            if isDestroyed then
                logger.error("Tried to access widget after it was destroyed")
            end

            if not isWidget(child) then
                logger.error("Cannot remove child that is not Widget!")
            end

            local childParent = child.getParent()
            if childParent and childParent._uniqueId ~= instance._uniqueId then
                logger.error("Child had different parent!")
            end

            logger.debug("[%s %d] Removing child: %s %d", instance._widgetName, id, child._widgetName, child._uniqueId)
            -- Swap and pop!!!
            local index = childrenIndex[child]
            if index ~= nil then
                local lastIndex = #children

                if index ~= lastIndex then
                    local newOccupier = children[lastIndex]

                    children[index] = newOccupier
                    childrenIndex[newOccupier] = index
                end

                children[lastIndex] = nil
                childrenIndex[child] = nil
            end

            if andDestroy == true then
                child.destroy()
            else
                child._setParent(nil)
            end
            events.fire("ChildRemoved", child)
        end

        function instance.clearChildren()
            ensureNotDestroyed()
            local toDestroy = table.clone(children)
            table.clear(children)
            table.clear(childrenIndex)

            for _, child in pairs(toDestroy) do
                child._setParent(nil)
                child.destroy()
            end
        end
    end

    if features.modifiers then
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
                            newMod.mountTo(object :: GuiObject)
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

        instance.setModifier = setModifier

        function instance.getModifier(name: string, index: number?)
            return modifierComponents[`{name}_{index or 1}`]
        end

        if args and args.modifiers then
            for key, modifierProps in pairs(args.modifiers) do
                -- modifierProps can't be nil... Impossible! MAYBE
                -- (And yea, linter was screaming at me AGAIN)
                setModifier(key, modifierProps :: any)
            end
        end
    end

    if features.transitions then
        function instance.setTransition(key: string, transition: Animations.Transition?)
            ensureNotDestroyed()

            if transition and not linkedProperties[key] then
                logger.warn("Transition was set on property that is not linked to object (key: %s)", key)
            end

            if transitions[key] and object then
                transitions[key].stop(object, key)
            end

            if transition then
                if animatedProperty[key] and animatedProperty[key] ~= "transition" then
                    logger.error("Property is already occupied by another animator: %s", transition)
                    return
                end
                animatedProperty[key] = "transition"
            else
                animatedProperty[key] = nil
            end

            transitions[key] = transition
        end

        function instance.snapProperty(key: string, value: any | Utils.Ref<any>)
            ensureNotDestroyed()

            local cachedTransition = transitions[key]
            if not cachedTransition then
                setProperty(key, value)
                return
            end

            transitions[key] = nil

            if cachedTransition and object and linkedProperties[key] then
                cachedTransition.stop(object, linkedProperties[key])
            end

            setProperty(key, value)

            transitions[key] = cachedTransition
        end
    end

    if features.animations then
        local unwatchKeys: {[string]: () -> ()} = {}
        local animationControlCache: {[string]: Animations.AnimationControl} = {}

        function instance.getAnimation(name: string): Animations.AnimationControl?
            do
                local cached = animationControlCache[name]
                if cached then
                    return cached
                end
            end

            local animation = animations[name]
            if not animation then
                return nil
            end

            local animationControl = {}
            animationControl._typeName = "animationControl"

            function animationControl.animate()
                if object then
                    animation.animate(object)
                end
            end

            function animationControl.stop()
                if object then
                    animation.stop(object)
                end
            end

            function animationControl.isRunning()
                if object then
                    return animation.isRunning(object)
                end
                return false
            end

            function animationControl.pause()
                if object then
                    animation.pause(object)
                end
            end

            function animationControl.continue()
                if object then
                    animation.continue(object)
                end
            end

            table.freeze(animationControl)
            animationControlCache[name] = animationControl
            return animationControl
        end

        function instance.setAnimation(name: string, animation: Animations.Animation?)
            ensureNotDestroyed()

            if animation then
                for _, key in animation.properties do
                    local originalKey = linkedPropertiesMap[key]
                    if not originalKey then
                        continue
                    end

                    local animator = animatedProperty[originalKey]
                    if animator then
                        logger.error("Animation animates one of the properties that is already occupied by another animator: %s", animator)
                        return
                    end
                end
            end

            local oldAnimation = animations[name]
            if oldAnimation then
                if object and oldAnimation.isRunning(object) then
                    oldAnimation.stop(object)
                end

                for _, key in oldAnimation.properties do
                    local originalKey = linkedPropertiesMap[key]
                    if not originalKey then
                        continue
                    end

                    animatedProperty[originalKey] = nil
                    propertyToAnimation[originalKey] = nil

                    local unwatchFn = unwatchKeys[originalKey]
                    if unwatchFn then
                        unwatchFn()
                        unwatchKeys[originalKey] = nil
                    end
                end

                animations[name] = nil
            end

            if not animation then
                return
            end

            animations[name] = animation
            if object then
                animation.animate(object)
            end

            for _, key in animation.properties do
                local originalKey = linkedPropertiesMap[key]
                if not originalKey then
                    continue
                end

                animatedProperty[originalKey] = `animation_{name}`
                propertyToAnimation[originalKey] = animation

                local ref = ensureRef(originalKey)
                unwatchKeys[originalKey] = ref.watch(function()
                    local propertyAnimation = propertyToAnimation[originalKey]

                    if object and propertyAnimation and propertyAnimation.isRunning(object) then
                        propertyAnimation.stop(object)
                        propertyAnimation.animate(object)
                    end
                end)
            end
        end
    end
    -- feature: all -- end --

    if args and args.properties then
        for key, value in pairs(args.properties :: {[string]: any}) do
            setProperty(key, value)
        end
    end

    local setupOverride = args and args.defaultSetupOverride
    if setupOverride == Undefined then
        -- Nothing
    elseif setupOverride then
        (setupOverride :: any)(instance :: any, defaultSetup :: any)
    else
        defaultSetup(instance :: any)
    end

    if args then
        if args.events then
            for key, callback in pairs(args.events :: {[string]: any}) do
                listen(key, callback)
            end
        end

        if features.children and args.children then
            for _, child in ipairs(args.children) do
                instance.addChild(child :: Widget.InternalInterface)
            end
        end

        if features.transitions and args.transitions then
            for key, transition in pairs(args.transitions) do
                if not linkedProperties[key] then
                    logger.warn("Transition was set on property that is not linked to object (key: %s)", key)
                end

                instance.setTransition(key, transition)
            end
        end

        if features.animations and args.animations then
            for name, animation in pairs(args.animations) do
                instance.setAnimation(name, animation)
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

return WidgetClass