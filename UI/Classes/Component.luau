--!strict
--!optimize 2
const Utils = require(script.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Types.Widget)
const Context = require(script.Parent.Parent.Utils.Context)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Widget = require(script.Parent.Widget)

local logger = Logging.getLogger("PeanutUI.Classes.Component")

local Component = {}

local function getBucketOrError(): Utils.Bucket
    local currentBucket = Context.getCurrentBucket()
    if not currentBucket then
        logger.error("There's no component context available. Is it running in defineComponent?")
        error("")
    end

    return currentBucket
end

function Component.onSetup(fn: (widget: WidgetType.Interface) -> ())
    local bucket = getBucketOrError()
    bucket.hooks.add("OnSetup", fn)
end

function Component.onCreated(fn: (object: GuiObject) -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnCreated", fn :: any)
end

function Component.onBeforeDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnBeforeDestroyed", fn :: any)
end

function Component.onDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnDestroyed", fn :: any)
end

function Component.defineComponent<T>(
    fn: (props: T & {[string]: any}) -> any
): (props: T) -> WidgetType.Interface
    return function(props)
        local ok, widget, bucket = Context.withContext("component", fn, props)
        if not ok then
            logger.error("Couldn't create component because it errored")
        end

        if not widget or not Widget.isWidget(widget) then
            logger.error("Function in defineComponent has to return a widget!")
        end

        assert(bucket, "Bucket was nil? weird");

        (widget :: WidgetType.InternalInterface)._addCleanup(function()
            for _, ref in bucket.createdRefs do
                ref.destroy()
            end
        end)

        local fireHook = bucket.hooks.fire

        fireHook("OnSetup", widget)

        local guiObject = (widget :: WidgetType.Interface).getObject()
        if guiObject then
            fireHook("OnCreated", guiObject)
        else
            widget.listen("ObjectCreated", function()
                fireHook("OnCreated", guiObject)
                return true
            end)
        end

        widget.listen("Destroying", function()
            fireHook("OnBeforeDestroyed")
            return true
        end)

        widget.listen("Destroyed", function()
            fireHook("OnDestroyed")
            return true
        end)

        return widget
    end
end

return Component