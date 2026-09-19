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
    table.insert(bucket.onSetupHooks, fn)
end

function Component.onCreated(fn: (object: GuiObject) -> ...boolean)
    local bucket = getBucketOrError()
    table.insert(bucket.onCreatedHooks, fn)
end

function Component.onBeforeDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    table.insert(bucket.onBeforeDestroyedHooks, fn)
end

function Component.onDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    table.insert(bucket.onDestroyedHooks, fn)
end

function Component.defineComponent<T>(
    fn: (props: T & {[string]: any}) -> any
): (props: T) -> WidgetType.Interface
    return function(props)
        local ok, widget, bucket = Context.withContext(fn, props)
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

        for _, fn in bucket.onSetupHooks do
            fn(widget)
        end

        local guiObject = (widget :: WidgetType.Interface).getObject()
        if guiObject then
            for _, fn in bucket.onCreatedHooks do
                fn(guiObject)
            end
        else
            for _, fn in bucket.onCreatedHooks do
                widget.listen("ObjectCreated", fn)
            end
        end

        for _, fn in bucket.onBeforeDestroyedHooks do
            widget.listen("Destroying", fn)
        end

        for _, fn in bucket.onDestroyedHooks do
            widget.listen("Destroyed", fn)
        end

        return widget
    end
end

return Component