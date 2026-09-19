--!strict
--!optimize 2

const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)
const Scheduler = require(script.Parent.Parent.Parent.Utils.Scheduler)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Children")

local isWidget = Helpers.isWidget
local widgetsAreSame = Helpers.widgetsAreSame
local freezeAndClear = Helpers.freezeAndClear
local readonly = Helpers.readonly

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    hooks: Utils.Hooks,
    events: Utils.Events
): {WidgetType.InternalInterface}
    local fire = events.fire
    local hooksFire = hooks.fire

    local nextLayoutOrder = 0
    local instance = widget :: WidgetType.BaseInterface
    local id = instance._uniqueId

    local children: {WidgetType.InternalInterface} = {}
    local childrenIndex: {[WidgetType.InternalInterface]: number} = {}

    instance.children = readonly(children)

    function instance.addChild(child_: WidgetType.WidgetLike)
        ensureNotDestroyed()
        local child = child_ :: WidgetType.InternalInterface

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

        if instance.isImplemented("getObject") and instance.getObject() and child.isImplemented("_createObject") then
            child._createObject()
        end

        fire("ChildAdded", child)
        hooksFire("ChildAdded", child)
    end

    function instance.removeChild(child_: WidgetType.WidgetLike, andDestroy: boolean?)
        ensureNotDestroyed()

        local child = child_ :: WidgetType.InternalInterface

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
            child._setParent(nil)
            child.destroy()
        else
            child._setParent(nil)
        end
        fire("ChildRemoved", child)
        hooksFire("ChildRemoved", child)
    end

    function instance.clearChildren()
        ensureNotDestroyed()
        table.clear(childrenIndex)

        for _, child in pairs(children) do
            child._setParent(nil)
            child.destroy()
        end

        table.clear(children)
    end

    instance._addCleanup(function()
        for _, child in ipairs(children :: any) do
            child._setParent(nil)
            child.destroy()
        end

        freezeAndClear(children)
        freezeAndClear(childrenIndex)
    end)

    hooks.add("ObjectCreateScheduled", function()
        for _, child in ipairs(children) do
            child._createObject()
        end
    end)

    return children
end
