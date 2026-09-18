--!strict
--!optimize 2
const Box = require(script.Parent.Parent.Classes.Box)
const Utils = require(script.Parent.Parent.Types.Utils)
const Widget = require(script.Parent.Parent.Types.Widget)
const ComponentContext = require(script.Parent.Parent.Utils.ComponentContext)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Ref = require(script.Parent.Parent.Utils.Ref)

local logger = Logging.getLogger("PeanutUI.Components.ControlFlow")

local ControlFlow = {}

export type ConditionOrRef = boolean | Utils.Ref<boolean>
export type WidgetFn<Props...> = (Props...) -> Widget.WidgetLike
export type Materialize = {
    build: () -> Widget.Box
}
export type IfFlow = {
    ElseIf: <Props...>(
        conditionOrRef: ConditionOrRef,
        widgetFn: WidgetFn<Props...>, Props...
    ) -> IfFlow & Materialize,
    Else: <Props...>(
        widgetFn: WidgetFn<Props...>,
        Props...
    ) -> Materialize,
}

type Branch = {
    conditionOrRef: ConditionOrRef,
    createFn: WidgetFn<any>,
    props: {any}
}

local function addBranch(
    branches: {Branch},
    conditionOrRef: ConditionOrRef,
    createFn: WidgetFn<any>,
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
    widgetFn: WidgetFn<Props...>,
    ...: Props...
): IfFlow & Materialize
    local branches = Ref.reactive({}) :: {Branch}
    local branchesRef = Ref.getRef(branches) :: Utils.Ref<{Branch}>

    addBranch(branches, conditionOrRef, widgetFn, ...)

    local branch = Ref.autoComputed(function(use)
        for _, branch in use(branchesRef) do
            local conditionOrRef = branch.conditionOrRef
            local condition: boolean

            if Ref.isRef(conditionOrRef) then
                condition = use(conditionOrRef :: Utils.Ref<boolean>)
            else
                condition = conditionOrRef :: boolean
            end
            
            if condition then
                return branch :: Branch?
            end
        end

        return nil
    end) :: Utils.Ref<Branch?>

    local flow: IfFlow & Materialize
    flow = {
        ElseIf = function(conditionOrRef, widgetFn, ...)
            addBranch(branches, conditionOrRef, widgetFn, ...)
            return {
                ElseIf = flow.ElseIf,
                Else = flow.Else,
                build = flow.build
            }
        end,
        Else = function(widgetFn, ...)
            addBranch(branches, true, widgetFn, ...)
            return {
                build = flow.build
            }
        end,
        build = function()
            local box = Box.new()
            box._boxName = "if"

            local oldWidget: Widget.WidgetLike? = nil
            local unwatch = branch.watch(function(newBranch)
                if oldWidget then
                    box.removeChild(oldWidget)
                    oldWidget.destroy()
                    oldWidget = nil
                end

                if newBranch then
                    local ok, result = ComponentContext.withNoContext(function(...)
                        assert(newBranch)
                        return newBranch.createFn(table.unpack(newBranch.props))
                    end)

                    if not ok then
                        logger.warn("Couldn't get widget for If because it errored: %s", tostring(result))
                        return
                    end

                    box.addChild(result)
                    oldWidget = result
                end
            end)

            box._addCleanup(function()
                unwatch()

                if oldWidget then
                    oldWidget.destroy()
                    oldWidget = nil
                end

                branch.destroy();
                (Ref.getRef(branches) :: any).destroy()
            end)

            table.clear(flow)
            return box
        end
    }

    return flow
end

return ControlFlow