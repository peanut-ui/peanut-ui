--!strict
--!optimize 2
const WidgetFeatures = require(script.Parent)
const Animations = require(script.Parent.Parent.Parent.Types.Animations)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Transitions")

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    hooks: Utils.Hooks,
    transitions: {[string]: Animations.Transition}?,
    animatedProperty: {[string]: string}?,
    linkedProperties: {[string]: string}?,
    setTransitions: {[string]: Animations.Transition}?
)
    WidgetFeatures.requireField(logger, widget, "getObject")
    WidgetFeatures.requireFeature(logger, widget, "properties")
    local instance = widget :: WidgetType.BaseInterface

    assert(linkedProperties ~= nil, "linkedProperties cannot be nil")
    assert(transitions ~= nil, "transitions cannot be nil")
    assert(animatedProperty ~= nil, "animatedProperty cannot be nil")

    function instance.setTransition(key: string, transition: Animations.Transition?)
        ensureNotDestroyed()

        local object = instance.getObject()

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

        local object = instance.getObject()

        local cachedTransition = transitions[key]
        if not cachedTransition then
            instance.setProperty(key, value)
            return
        end

        transitions[key] = nil

        if cachedTransition and object and linkedProperties[key] then
            cachedTransition.stop(object, linkedProperties[key])
        end

        instance.setProperty(key, value)

        transitions[key] = cachedTransition
    end

    instance._addCleanup(function()
        local object = instance.getObject()

        if object then
            for _, transition in pairs(transitions) do
                transition.stop(object)
            end
        end
    end)

    hooks.add("OnSetup", function()
        if setTransitions then
            for key, transition in pairs(setTransitions) do
                if not linkedProperties[key] then
                    logger.warn("Transition was set on property that is not linked to object (key: %s)", key)
                end

                instance.setTransition(key, transition)
            end
        end
    end)
end
