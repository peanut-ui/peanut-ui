--!strict
--!optimize 2
const Box = require(script.Parent.Parent.Classes.Box)
const Utils = require(script.Parent.Parent.Types.Utils)
const Widget = require(script.Parent.Parent.Types.Widget)
const Context = require(script.Parent.Parent.Utils.Context)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)

local logger = Logging.getLogger("PeanutUI.Components.ControlFlow")

local ControlFlow = {}

export type ConditionOrRef = boolean | Utils.SimpleRef<boolean>
export type Materialize = {
    End: () -> Widget.Box
}
export type IfFlow = {
    ElseIf: <Props...>(
        conditionOrRef: ConditionOrRef,
        widgetFn: (Props...) -> Widget.WidgetLike,
        Props...
    ) -> IfFlow & Materialize,
    Else: <Props...>(
        widgetFn: (Props...) -> Widget.WidgetLike,
        Props...
    ) -> Materialize,
}

type Branch = {
    conditionOrRef: ConditionOrRef,
    createFn:(any) -> Widget.WidgetLike,
    props: {[number]: any, n: number}
}

local function addBranch(
    branches: {Branch},
    conditionOrRef: ConditionOrRef,
    createFn: (any) -> Widget.WidgetLike,
    ...: any
)
    local branch: Branch = {
        conditionOrRef = conditionOrRef,
        createFn = createFn,
        props = table.pack(...)
    }
    branches[#branches + 1] = branch
end

function ControlFlow.If<Props...>(
    conditionOrRef: ConditionOrRef,
    widgetFn: (Props...) -> Widget.WidgetLike,
    ...: Props...
): IfFlow & Materialize
    local branches = {} :: {Branch}

    addBranch(branches, conditionOrRef, widgetFn, ...)

    local flow: IfFlow & Materialize
    flow = {
        ElseIf = function(conditionOrRef, widgetFn, ...)
            addBranch(branches, conditionOrRef, widgetFn, ...)
            return flow
        end,
        Else = function(widgetFn, ...)
            addBranch(branches, true, widgetFn, ...)
            return {
                End = flow.End
            }
        end,
        End = function()
            local box = Box.new()
            box._boxName = "if"

            table.freeze(branches)
            local oldWidget: Widget.WidgetLike? = nil

            local branch = Ref.computed(function()
                for _, branch in branches do
                    local conditionOrRef = branch.conditionOrRef
                    local condition: boolean

                    if Ref.isRef(conditionOrRef) then
                        condition = (conditionOrRef :: Utils.Ref<boolean>).value
                    else
                        condition = conditionOrRef :: boolean
                    end

                    if condition then
                        return branch :: Branch?
                    end
                end

                return nil
            end)

            local oldBranch: Branch? = nil
            local function update(newBranch: Branch?)
                if oldBranch == newBranch then return end
                oldBranch = newBranch

                if oldWidget then
                    box.removeChild(oldWidget)
                    oldWidget.destroy()
                    oldWidget = nil
                end

                if newBranch then
                    local ok, result = Context.withNoContext(function(...)
                        assert(newBranch)
                        local props = newBranch.props
                        return newBranch.createFn(table.unpack(props, 1, props.n))
                    end)

                    if not ok then
                        logger.warn("Couldn't get widget for If because it errored: %s", tostring(result))
                        return
                    end

                    box.addChild(result)
                    oldWidget = result
                end
            end

            local unwatch = branch.watch(update)
            update(branch.getValue())

            box._addCleanup(function()
                unwatch()
                oldWidget = nil

                branch.destroy()
            end)

            table.clear(flow)
            return box
        end
    }

    return flow
end

--- Static for loop
function ControlFlow.For<K, V>(
    array: {[K]: V},
    createFn: (value: V, index: K) -> Widget.WidgetLike
): Widget.Box
    local box = Box.new()
    box._boxName = "for"

    for i, item in array do
        box.addChild(createFn(item, i))
    end

    return box
end

function ControlFlow.ReactiveFor<K, V>(
    array: {[K]: V},
    createFn: (value: V) -> Widget.WidgetLike,
    keyFn: ((value: V, index: K) -> any)
)
    local arrayRef = Ref.getRef(array)
    if not arrayRef then
        logger.error("Cannot do ReactiveFor on plain table. HINT: Use simple For for static tables, or wrap table in reactive.")
    end

    if not Ref.isShallow(array) then
        logger.warn("It's generally recommended to use shallow reactive for ReactiveFor so nested tables don't cause recalculations.")
    end

    local box = Box.new()
    box._boxName = "reactiveFor"

    local widgets: {[any]: Widget.WidgetLike} = {}

    local bucket = (Context.getCurrentBucket() or false) :: any

    local function populate()
        -- Key from keyFn -> array value
        local newKeys: {[any]: any} = {}
        for key, value in arrayRef.value do
            local k = keyFn(value, key)
            if newKeys[k] then
                logger.warn("Detected key collision, latest value will be used. Key: %s", k)
            end
            newKeys[k] = value
        end

        for key, value in newKeys do
            if not widgets[key] then
                local ok, result = Context.withContextBucket(bucket, function()
                    return createFn(value)
                end)

                if not ok then
                    logger.warn("There was an error during ReactiveFor widget creation: %s", result)
                    continue
                end

                widgets[key] = result
                box.addChild(result)
            end
        end

        for key, widget in widgets do
            if not newKeys[key] then
                widgets[key] = nil
                box.removeChild(widget, true)
            end
        end
    end
    populate()

    arrayRef.watch(populate)

    return box
end

function ControlFlow.Lazy<A...>(
    createFn: (A...) -> Widget.WidgetLike,
    ...: A...
)
    local box, hooks = Box.new()
    box._boxName = "lazy"

    local args: {[number]: any, n: number}? = nil
    if select("#", ...) > 0 then
        args = table.pack(... :: any)
    end

    local bucket = Context.getCurrentBucket() or false

    hooks.add("ObjectCreateScheduled", function()
        local ok, result = Context.withContextBucket(bucket :: any, function()
            if args then
                return createFn(table.unpack(args, 1, args.n))
            else
                return (createFn :: () -> Widget.WidgetLike)()
            end
        end)

        if not ok then
            logger.warn("There was an error during lazy widget creation: %s", result)
            return
        end

        box.addChild(result)
        if result.isImplemented("_createObject") then
            (result :: Widget.BaseInterface)._createObject()
        end
    end)

    return box
end

return table.freeze(ControlFlow)