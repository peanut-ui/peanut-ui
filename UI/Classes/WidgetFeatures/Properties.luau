--!strict
--!optimize 2
const WidgetFeatures = require(script.Parent)
const Animations = require(script.Parent.Parent.Parent.Types.Animations)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Parent.Utils.Ref)
const Scheduler = require(script.Parent.Parent.Parent.Utils.Scheduler)
const Undefined = require(script.Parent.Parent.Parent.Utils.Undefined)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Properties")

local freezeAndClear = Helpers.freezeAndClear

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    transitions: {[string]: Animations.Transition}?,
    hooks: Utils.Hooks,
    bucket: Utils.Bucket,
    events: Utils.Events,
    setProperties: {[string]: any}?
)
    WidgetFeatures.requireField(logger, widget, "getObject")

    local fire = events.fire
    local instance = widget :: WidgetType.BaseInterface
    local id = instance._uniqueId

    local inRedrawMode = false
    local stopped = false

    local propertiesRefs: {[string]: Utils.Ref<any>} = {}

    local linkedProperties: {[string]: string} = {}
    local linkedPropertiesUpdate: {[string]: () -> ()} = {}
    local linkedPropertiesMap: {[string]: string} = {}

    local readonlyProperties: {[string]: boolean} = {}

    local rbxLinkedProperties: {[string]: string} = {}
    local rbxPropertyEvent: {[string]: RBXScriptConnection} = {}
    local rbxPropertyLocked: {[string]: boolean} = {}
    local rbxPropertyWatching: {[string]: number} = {}
    local rbxPropertyTransform: {[string]: (WidgetType.WidgetLike, any) -> any} = {}

    instance._propertiesRefs = propertiesRefs

    local function ensureRef(key: string)
        local ref = propertiesRefs[key]

        if not ref then
            propertiesRefs[key] = Ref.new(nil, nil, bucket)
            ref = propertiesRefs[key]
        end

        return ref
    end

    function instance.setProperty(key: string, value: any | Utils.Ref<any>)
        ensureNotDestroyed()

        local ref = ensureRef(key)

        value = Helpers.removeUndefined(value)

        if readonlyProperties[key] == true then
            logger.error("Cannot set readonly property")
        end

        if typeof(value) == "table" and value._typeName ~= "ref" then
            value = Ref.reactive(value)
        end

        ref.setValue(value)
        fire("PropertyChanged", key, ref.getValue())
    end

    local function syncRbxProperty(key: string)
        local rbxKey = rbxLinkedProperties[key]
        if not rbxKey then
            return
        end

        local object = instance.getObject()
        if not object then
            return
        end

        local ref = ensureRef(key)

        rbxPropertyLocked[key] = true
        local value = (object :: any)[rbxKey]

        local transformFn = rbxPropertyTransform[key]
        if transformFn then
            value = transformFn(instance, value)
        end

        local old = ref.getValue()
        if old ~= value then
            ref.setValue(value)
            fire("PropertyChanged", key, value)
        end

        rbxPropertyLocked[key] = nil
    end

    function instance._linkProperty(
        name: string,
        property: string,
        transformFn: ((WidgetType.WidgetLike, any) -> any)?,
        syncWithObject: (boolean | (WidgetType.WidgetLike, any) -> any)?,
        readonly: boolean?,
        redrawOnHooks: {string}?
    )
        ensureNotDestroyed()
        if linkedProperties[name] then
            logger.error("Cannot link property that is already linked, tried to link %s", name)
        end

        logger.debug(
            "[%s %d] Linking property. Name %s, Property %s, Transform %s, Sync %s, Readonly %s",
            instance._widgetName, id, name, property, typeof(transformFn), typeof(syncWithObject),
            readonly or false
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
            linkedPropertiesUpdate[name] = function()
                syncRbxProperty(name)
            end
            return
        end

        local function update()
            if stopped then return end
            if rbxPropertyLocked[name] == true then
                logger.debug("[%s %d] Skipped update of %s cause it's locked", instance._widgetName, id, name)
                return
            end

            local value = ref.getValue()
            local object = instance.getObject()
            if object then
                if value == Undefined then
                    value = nil
                end

                if transformFn then
                    value = transformFn(instance, value)
                end

                local oldValue = (object :: any)[property]
                if value == oldValue then
                    return
                end

                logger.debug(
                    "[%s %d] Updating property %s to %s (type %s)",
                    instance._widgetName, id, name, value, typeof(value)
                )

                if inRedrawMode then
                    if transitions and transitions[name] then
                        transitions[name].stop(object, property)
                    end
                    (object :: any)[property] = value
                elseif transitions and transitions[name] then
                    transitions[name].animate(object, property, value)
                else
                    (object :: any)[property] = value
                end
            end
        end

        local scheduled = false
        local function scheduledUpdate()
            if rbxPropertyLocked[name] == true then
                logger.debug("[%s %d] Skipped scheduled update of %s cause it's locked", instance._widgetName, id, name)
                return
            end

            if scheduled then return end
            scheduled = true

            Scheduler.schedule("redraw", function()
                scheduled = false
                update()
            end)
        end

        linkedPropertiesUpdate[name] = update
        ref.watch(
            scheduledUpdate, { bucket = bucket, flush = "sync" }
        )

        if redrawOnHooks then
            for _, hook in ipairs(redrawOnHooks) do
                hooks.add(hook, function()
                    inRedrawMode = true
                    update()
                    inRedrawMode = false
                end)
            end
        end
    end

    function instance.getProperty(key: any): any
        ensureNotDestroyed()

        local ref = propertiesRefs[key]
        if not ref then
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

    local function checkRbxPropertyEvent(key: string)
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
            local object = instance.getObject()
            if not object then
                return
            end

            rbxPropertyEvent[key] = object:GetPropertyChangedSignal(rbxLinkedProperties[key]):Connect(function(value)
                if transitions and object and transitions[key] and transitions[key].isRunning(object, rbxKey) then
                    return
                end
                syncRbxProperty(key)
            end)
        end
    end

    function instance.observe(key: string, callback: (newValue: any) -> ...boolean?): () -> ()
        ensureNotDestroyed()

        local ref = ensureRef(key)

        if rbxLinkedProperties[key] then
            local counter = rbxPropertyWatching[key] or 0
            rbxPropertyWatching[key] = counter + 1

            checkRbxPropertyEvent(key)
        end

        local unwatch, id = ref.watch(callback, { bucket = bucket })

        local function onUnwatch()
            if rbxLinkedProperties[key] then
                local counter = rbxPropertyWatching[key] or 0
                rbxPropertyWatching[key] = counter - 1

                checkRbxPropertyEvent(key)
            end
        end

        ref.setOnUnwatch(id, onUnwatch)

        return unwatch
    end

    function instance.getRef(key: string): Utils.ProtectedRef<any>
        ensureNotDestroyed()

        local ref = ensureRef(key)

        local onWatch: (...any) -> ()? = nil
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

    hooks.add("OnRedraw", function()
        inRedrawMode = true

        for key, _ in pairs(rbxLinkedProperties) do
            syncRbxProperty(key)
        end

        for key, update in pairs(linkedPropertiesUpdate) do
            update()
        end

        inRedrawMode = false
    end)

    hooks.add("ObjectCreated", function()
        for key, _ in pairs(rbxPropertyWatching) do
            checkRbxPropertyEvent(key)
        end
    end)

    bucket.addCleanup(function()
        stopped = true
        for key, signal in pairs(rbxPropertyEvent) do
            signal:Disconnect()
        end

        freezeAndClear(propertiesRefs)
        freezeAndClear(linkedProperties)
        freezeAndClear(linkedPropertiesUpdate)
        freezeAndClear(linkedPropertiesMap)
        freezeAndClear(readonlyProperties)
        freezeAndClear(rbxLinkedProperties)
        freezeAndClear(rbxPropertyEvent)
        freezeAndClear(rbxPropertyLocked)
        freezeAndClear(rbxPropertyWatching)
        freezeAndClear(rbxPropertyTransform)
    end)

    if setProperties then
        for key, value in pairs(setProperties) do
            instance.setProperty(key, value)
        end
    end

    return linkedProperties, linkedPropertiesMap, propertiesRefs, transitions, ensureRef
end
