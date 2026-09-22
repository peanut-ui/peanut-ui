--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Classes.Widget)
const Utils = require(script.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Types.Widget)
const Context = require(script.Parent.Parent.Utils.Context)
const Logging = require(script.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Components.Component")

local Component = {}

local function getBucketOrError(): Utils.Bucket
    local currentBucket = Context.getCurrentBucket()
    if not currentBucket then
        logger.error("There's no component context available. Is it running in defineComponent?")
        error("")
    end

    return currentBucket
end

--- Registers a callback that runs after the component function has created its widget.
--- The callback receives the component's root widget.
---
--- Must be called while a component is being defined.
--- @param fn A callback that receives the component's root widget
function Component.onSetup(fn: (widget: WidgetType.Interface) -> ())
    local bucket = getBucketOrError()
    bucket.hooks.add("OnSetup", fn)
end

--- Registers a callback that runs when the component's Roblox GUI object is created.
---
--- Must be called while a component is being defined.
--- @param fn A callback that receives the created GUI object
function Component.onCreated(fn: (object: GuiObject) -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnCreated", fn :: any)
end

--- Registers a callback that runs before the component begins destruction.
--- The component's widget and GUI object are still available at this point.
---
--- Must be called while a component is being defined.
--- @param fn A cleanup callback
function Component.onBeforeDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnBeforeDestroyed", fn :: any)
end

--- Registers a callback that runs after the component has been destroyed.
--- The component's widget, refs, and GUI object are no longer available.
---
--- Must be called while a component is being defined.
--- @param fn A callback that runs after destruction
function Component.onDestroyed(fn: () -> ...boolean)
    local bucket = getBucketOrError()
    bucket.hooks.add("OnDestroyed", fn :: any)
end

--- Creates a component with lifecycle controls.
---
--- *Fun fact:* You can pass Ref.reactive table to props and then use Ref.swap/Ref.deepSwap
--- and use Ref.toRef(props, "key") inside of components to get reactive props.
---
--- **IMPORTANT:** If you create any Ref inside the component after the component is destroyed
--- all the Refs are gonna be destroyed too, so pass Refs only down to children,
--- don't pass them to places outside of Component lifecycle.
--- Refs created outside of Component and passed through props are okay.
---
--- @param fn A function that creates components out of props and returns widget
--- @return A function that creates the widget and passes the provided props to it
---
--- ### Example
--- ```
--- local Test = Component.defineComponent(function(props: { test: string })
---     -- This is called immediately after `fn` was called
---     Component.onSetup(function(widget: Widgets.TextLabel)
---         print("Widget setup!")
---     end)
---     -- This is called when roblox object is created
---     Component.onCreated(function(object: TextLabel)
---         print("Roblox object created!")
---     end)
---     -- Widget and object are still available here
---     Component.onBeforeDestroyed(function()
---         print("Cleaning up!!")
---     end)
---     -- Widget, refs and object aren't available anymore here
---     Component.onDestroyed(function()
---         print("Widget is dead...")
---     end)
---     -- Return root widget!!
---     return Widgets.TextLabel {
---         properties = { text = props.test }
---     }
--- end)
--- local object = Test({ test = "Hello there." })
--- ```
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