--!strict
--!optimize 2
const Modifier = require(script.Parent.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Parenting")

local isWidget = Helpers.isWidget
local widgetsAreSame = Helpers.widgetsAreSame

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    children: {any}?,
    modifierComponents: {[string]: Modifier.Component}?,
    events: Utils.Events,
    hooks: Utils.Hooks
)
    local fire = events.fire
    local hooksFire = hooks.fire
    local instance = widget :: WidgetType.BaseInterface

    local space: WidgetType.SpaceLike? = nil
    local parent: WidgetType.Interface? = nil

    function instance.setParent(newParent: WidgetType.WidgetLike?)
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
            parent.removeChild(instance)
        end

        if newParent then
            (newParent :: WidgetType.Interface).addChild(widget)
        end
    end

    function instance.getSpace()
        return space
    end

    function instance._setSpace(newSpace: WidgetType.SpaceLike?)
        space = newSpace

        if children then
            for _, child in children do
                if child.isImplemented("_setSpace") then
                    child._setSpace(newSpace)
                end
            end
        end

        if modifierComponents then
            for _, modifier in modifierComponents do
                modifier.setScaleObjectFn(newSpace and newSpace.scaleObject)
            end
        end

        if instance.isImplemented("_redraw") then
            instance._redraw()
        end

        hooksFire("SpaceChanged", space)
    end

    function instance._setParent(newParent: WidgetType.WidgetLike?)
        ensureNotDestroyed()

        parent = newParent :: any

        if parent and parent._typeName == "space" then
            instance._setSpace(parent :: any)
        elseif parent and parent.isImplemented("getSpace") then
            local parentSpace = parent.getSpace()
            instance._setSpace(parentSpace)
        elseif space ~= nil then
            instance._setSpace(nil)
        end

        if instance.isImplemented("getObject") then
            local object = instance.getObject()
            if parent and parent.getObject() and object then
                object.Parent = parent.getObject()
            elseif not parent and object then
                object.Parent = nil
            end
        end

        fire("ParentChanged", newParent)
        hooksFire("ParentChanged", newParent)
    end

    function instance.getParent()
        return parent
    end

    instance._addCleanup(function()
        if parent then
            parent.removeChild(instance)
        end
    end)
end
