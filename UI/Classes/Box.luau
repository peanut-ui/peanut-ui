--!strict
--!optimize 2
const Utils = require(script.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Types.Widget)
const Events = require(script.Parent.Parent.Utils.Events)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Hooks = require(script.Parent.Parent.Utils.Hooks)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)
const Widget = require(script.Parent.Widget)
const Children = require(script.Parent.WidgetFeatures.Children)
const Parenting = require(script.Parent.WidgetFeatures.Parenting)

-- Thanks to WidgetFeatures, this is SO small

local logger = Logging.getLogger("PeanutUI.Classes.Box")

local Box = {}

local freezeAndClear = Helpers.freezeAndClear

function Box.new(): WidgetType.Box
    local box = Widget.createEmptyWidget() :: WidgetType.Box
    box._typeName = "box"
    box._widgetLike = true
    box._widgetName = "box"
    box._boxName = "box"
    box._features["parenting"] = true
    box._features["children"] = true
    box._features["events"] = true

    local hooks = Hooks.new()
    local events = Events.new()

    local fire = events.fire
    local fireHook = hooks.fire

    local cleanups: {RBXScriptConnection | () -> ()} = {}
    local isDestroyed = false

    local objectRef = Ref.new(nil) :: Utils.Ref<Instance?>

    -- box: main -- start --
    local function ensureNotDestroyed()
        if isDestroyed then
            logger.error("[%s %d] Tried to access widget after it was destroyed", box._boxName, box._uniqueId)
        end
    end

    local isDestroying = false
    function box.destroy()
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
    end

    function box.isDestroyed()
        return isDestroyed
    end

    function box._addCleanup(toCleanup: RBXScriptConnection | () -> ())
        ensureNotDestroyed()
        table.insert(cleanups, toCleanup)
    end
    -- box: main -- end --

    -- feature: events -- start --
    local function listen(name: string, callback: (...any) -> ...boolean?): () -> ()
        ensureNotDestroyed()
        return events.listen(name, callback)
    end
    box.listen = listen

    function box._linkEvent(...)
        logger.error("Box doesn't have underlying Instance so it can't link events")
    end
    -- feature: events -- end --


    -- widget: object -- start --
    function box.getObject(): Instance?
        local parent = box.getParent()
        return parent and parent.getObject()
    end

    function box.getObjectRef(): Utils.ProtectedRef<Instance?>
        return Ref.makeProtected(objectRef :: any)
    end

    function box._redraw()
        for _, child in box.children do
            if not child.isImplemented("_redraw") then
                continue
            end

            child._redraw()
        end
    end

    function box._createObject()
        fireHook("ObjectCreateScheduled")
        return nil
    end
    -- widget: object -- end --

    -- features: all -- start --
    local children = Children(
        box,
        ensureNotDestroyed,
        hooks,
        events
    )

    Parenting(
        box,
        ensureNotDestroyed,
        children,
        nil,
        events,
        hooks
    )
    -- features: all -- end --

    hooks.add("ParentChanged", function(newParent: WidgetType.BaseInterface?)
        if newParent and newParent.isImplemented("getObjectRef") then
            objectRef.setValue(newParent.getObjectRef())
        else
            objectRef.setValue(nil)
        end
    end)

    return box
end

return table.freeze(Box)