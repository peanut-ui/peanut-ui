--!strict
--!optimize 2
const WidgetFeatures = require(script.Parent)
const Animations = require(script.Parent.Parent.Parent.Types.Animations)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Animations")

local freezeAndClear = Helpers.freezeAndClear

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    hooks: Utils.Hooks,
    animatedProperty: {[string]: string}?,
    linkedProperties: {[string]: string}?,
    linkedPropertiesMap: {[string]: string}?,
    ensureRef: ((string) -> Utils.Ref<any>)?,
    setAnimations: {[string]: Animations.Animation}?
)
    WidgetFeatures.requireField(logger, widget, "_addCleanup")
    WidgetFeatures.requireField(logger, widget, "getObject")
    WidgetFeatures.requireFeature(logger, widget, "properties")

    assert(linkedProperties ~= nil, "linkedProperties cannot be nil")
    assert(linkedPropertiesMap ~= nil, "linkedPropertiesMap cannot be nil")
    assert(animatedProperty ~= nil, "animatedProperty cannot be nil")
    assert(ensureRef ~= nil, "animatedProperty cannot be nil")

    local animations: {[string]: Animations.Animation} = {}
    local propertyToAnimation: {[string]: Animations.Animation} = {}

    local instance = widget :: WidgetType.BaseInterface

    local unwatchKeys: {[string]: () -> ()} = {}
    local animationControlCache: {[string]: Animations.AnimationControl} = {}

    function instance.getAnimation(name: string): Animations.AnimationControl?
        ensureNotDestroyed()
        do
            local cached = animationControlCache[name]
            if cached then
                return cached
            end
        end

        local animation = animations[name]
        if not animation then
            return nil
        end

        local animationControl = {}
        animationControl._typeName = "animationControl"

        function animationControl.animate()
            local object = instance.getObject()
            if object then
                animation.animate(object)
            end
        end

        function animationControl.stop()
            local object = instance.getObject()
            if object then
                animation.stop(object)
            end
        end

        function animationControl.isRunning()
            local object = instance.getObject()
            if object then
                return animation.isRunning(object)
            end
            return false
        end

        function animationControl.pause()
            local object = instance.getObject()
            if object then
                animation.pause(object)
            end
        end

        function animationControl.continue()
            local object = instance.getObject()
            if object then
                animation.continue(object)
            end
        end

        table.freeze(animationControl)
        animationControlCache[name] = animationControl
        return animationControl
    end

    function instance.setAnimation(name: string, animation: Animations.Animation?)
        ensureNotDestroyed()
        local object = instance.getObject()

        if animation then
            for _, key in animation.properties do
                local originalKey = linkedPropertiesMap[key]
                if not originalKey then
                    logger.warn("Animation expected key %s but it's not linked, this might be a bug", key)
                    continue
                end

                local animator = animatedProperty[originalKey]
                if animator then
                    logger.error("Animation animates one of the properties that is already occupied by another animator: %s", animator)
                    return
                end
            end
        end

        local oldAnimation = animations[name]
        if oldAnimation then
            if object and oldAnimation.isRunning(object) then
                oldAnimation.stop(object)
            end

            for _, key in oldAnimation.properties do
                local originalKey = linkedPropertiesMap[key]
                if not originalKey then
                    logger.warn("Animation expected key %s but it's not linked, this might be a bug", key)
                    continue
                end

                animatedProperty[originalKey] = nil
                propertyToAnimation[originalKey] = nil

                local unwatchFn = unwatchKeys[originalKey]
                if unwatchFn then
                    unwatchFn()
                    unwatchKeys[originalKey] = nil
                end
            end

            animations[name] = nil
        end

        if not animation then
            return
        end

        animations[name] = animation
        if object then
            animation.animate(object)
        end

        for _, key in animation.properties do
            local originalKey = linkedPropertiesMap[key]
            if not originalKey then
                logger.warn("Key %s is not linked, so cannot listen to changes")
                continue
            end

            animatedProperty[originalKey] = `animation_{name}`
            propertyToAnimation[originalKey] = animation

            local ref = ensureRef(originalKey)
            unwatchKeys[originalKey] = ref.watch(function()
                local object = instance.getObject()
                local propertyAnimation = propertyToAnimation[originalKey]

                if object and propertyAnimation and propertyAnimation.isRunning(object) then
                    propertyAnimation.stop(object)
                    propertyAnimation.animate(object)
                end
            end)
        end
    end

    instance._addCleanup(function()
        local object = instance.getObject()
        if object then
            for _, animation in animations do
                animation.stop(object)
            end
        end

        freezeAndClear(animations)
        freezeAndClear(propertyToAnimation)
    end)

    hooks.add("AfterRedraw", function(object: GuiObject)
        for _, animation in pairs(animations) do
            animation.animate(object)
        end
    end)

    return function()
        if setAnimations then
            for name, animation in pairs(setAnimations) do
                instance.setAnimation(name, animation)
            end
        end
    end
end
