--!strict
--!optimize 2
const WidgetFeatures = require(script.Parent)
const Animations = require(script.Parent.Parent.Parent.Types.Animations)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)
const Scheduler = require(script.Parent.Parent.Parent.Utils.Scheduler)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Animations")

local freezeAndClear = Helpers.freezeAndClear

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    hooks: Utils.Hooks,
    bucket: Utils.Bucket,
    animatedProperty: {[string]: string}?,
    linkedProperties: {[string]: string}?,
    linkedPropertiesMap: {[string]: string}?,
    ensureRef: ((string) -> Utils.Ref<any>)?,
    setAnimations: {[string]: Animations.Animation}?
)
    WidgetFeatures.requireField(logger, widget, "getObject")
    WidgetFeatures.requireFeature(logger, widget, "properties")

    assert(linkedProperties ~= nil, "linkedProperties cannot be nil")
    assert(linkedPropertiesMap ~= nil, "linkedPropertiesMap cannot be nil")
    assert(animatedProperty ~= nil, "animatedProperty cannot be nil")
    assert(ensureRef ~= nil, "animatedProperty cannot be nil")

    local animationsToPlay: {[any]: boolean} = {}
    local animations: {[any]: Animations.Animation} = {}
    local propertyToAnimation: {[any]: Animations.Animation} = {}

    local instance = widget :: WidgetType.BaseInterface

    local unwatchKeys: {[any]: () -> ()} = {}
    local animationControlCache: {[any]: Animations.AnimationControl} = {}

    local scaleFnCached: ((any, boolean?) -> any)? = nil

    local function scale(value: any, getOriginal: boolean?): any
        if scaleFnCached then
            return scaleFnCached(value, getOriginal)
        end

        return value
    end

    local function updateScale()
        if not instance.isImplemented("getSpace") then
            return
        end

        local space = instance.getSpace()
        if not space then
            return
        end

        scaleFnCached = space.scaleObject
    end

    function instance.getAnimationControl(name: any): Animations.AnimationControl
        ensureNotDestroyed()
        do
            local cached = animationControlCache[name]
            if cached then
                return cached
            end
        end

        local animation = animations[name]
        if not animation then
            return nil :: any
        end

        local animationControl = {}
        animationControl._typeName = "animationControl"

        function animationControl.animate()
            ensureNotDestroyed()
            local object = instance.getObject()
            if object then
                animation.animate(object, scale)
                animationsToPlay[name] = nil
            else
                animationsToPlay[name] = true
            end
        end

        function animationControl.stop()
            ensureNotDestroyed()
            local object = instance.getObject()
            animationsToPlay[name] = nil
            if object then
                animation.stop(object)
            end
        end

        function animationControl.isRunning()
            ensureNotDestroyed()
            local object = instance.getObject()
            if object then
                return animation.isRunning(object)
            end
            return false
        end

        function animationControl.pause()
            ensureNotDestroyed()
            local object = instance.getObject()
            animationsToPlay[name] = nil
            if object then
                animation.pause(object)
            end
        end

        function animationControl.continue()
            ensureNotDestroyed()
            local object = instance.getObject()
            if object then
                animation.continue(object)
            end
        end

        table.freeze(animationControl)
        animationControlCache[name] = animationControl
        return animationControl
    end

    function instance.setAnimation(name: any, animation_: Animations.MaybeResolvedAnimation?, disableAutoPlay: boolean?)
        ensureNotDestroyed()
        local object = instance.getObject()

        local animation: Animations.Animation? = nil
        if not animation_ then
            -- Hi
        elseif animation_._typeName == "animation" then
            animation = animation_
        else
            animation = animation_.resolve(linkedProperties)
        end

        animationsToPlay[name] = nil

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
        if disableAutoPlay ~= true then
            if object then
                animation.animate(object, scale)
            else
                animationsToPlay[name] = true
            end
        end

        local restartScheduled = false
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
                if restartScheduled then return end

                local object = instance.getObject()
                local propertyAnimation = propertyToAnimation[originalKey]

                if object and propertyAnimation and propertyAnimation.isRunning(object) then
                    restartScheduled = true

                    propertyAnimation.stop(object)

                    Scheduler.scheduleAfter("redraw", function()
                        restartScheduled = false

                        local object = instance.getObject()
                        if not object or propertyToAnimation[originalKey] ~= propertyAnimation then
                            return
                        end

                        propertyAnimation.animate(object, scale)
                    end)
                end
            end, { bucket = bucket })
        end
    end

    bucket.addCleanup(function()
        local object = instance.getObject()
        if object then
            for _, animation in animations do
                animation.stop(object)
            end
        end

        freezeAndClear(animations)
        freezeAndClear(propertyToAnimation)
        freezeAndClear(animationsToPlay)
    end)

    hooks.add("AfterRedraw", function(object: GuiObject)
        updateScale()

        for name, _ in animationsToPlay do
            local animation = animations[name]
            if animation then
                animation.animate(object, scale)
                animationsToPlay[name] = nil
            end
        end
    end)

    hooks.add("SpaceChanged", function(...)
        updateScale()
    end)

    hooks.add("ScaleChanged", function(...)
        updateScale()
    end)

    hooks.add("OnSetup", function()
        if setAnimations then
            for name, animation in pairs(setAnimations) do
                instance.setAnimation(name, animation)
            end
        end
    end)
end
