--!strict
--!optimize 2
const WidgetFeatures = require(script.Parent)
const Modifiers = require(script.Parent.Parent.Modifiers)
const Modifier = require(script.Parent.Parent.Parent.Types.Modifier)
const Utils = require(script.Parent.Parent.Parent.Types.Utils)
const WidgetType = require(script.Parent.Parent.Parent.Types.Widget)
const Helpers = require(script.Parent.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Classes.WidgetFeatures.Modifiers")

local freezeAndClear = Helpers.freezeAndClear

return function(
    widget: any,
    ensureNotDestroyed: () -> (),
    hooks: Utils.Hooks,
    modifiers: Modifier.Modifiers?
): {[string]: Modifier.Component}
    WidgetFeatures.requireField(logger, widget, "getObject")
    WidgetFeatures.requireField(logger, widget, "_addCleanup")

    local modifierComponents: {[string]: Modifier.Component} = {}
    local instance = widget :: WidgetType.BaseInterface

    local function setModifier(name: string, params: {[string]: any} | { {[string]: any} })
        ensureNotDestroyed()

        local modifierFactory: (props: {[string]: any}) -> Modifier.Component

        do
            local component = Modifiers.components[name]
            if not component then
                logger.warn("Modifier with name %s doesn't exist", name)
                return
            end

            if typeof(component) == "string" then
                component = Modifiers.components[component]
                if not component or typeof(component) == "string" then
                    return
                end
                modifierFactory = component
            else
                modifierFactory = component
            end
        end

        if typeof(params) == "table" and typeof(params[1]) == "table" then
            for i, config in ipairs(params :: { {[string]: any} }) do
                local stackKey = `{name}_{i}`

                if Helpers.removeUndefined(config) == nil then
                    local component = modifierComponents[stackKey]
                    if component then
                        component.destroy()
                        modifierComponents[stackKey] = nil
                    end
                    return
                end

                if not modifierComponents[stackKey] then
                    local newMod = modifierFactory(config) :: any
                    modifierComponents[stackKey] = newMod

                    local object = instance.getObject()
                    if object then
                        newMod.mountTo(object)
                    end
                else
                    for k, v in pairs(config) do
                        modifierComponents[stackKey].setProperty(k, v)
                    end
                end
            end
        else
            local stackKey = `{name}_1`

            if Helpers.removeUndefined(params) == nil then
                local component = modifierComponents[stackKey]

                if component then
                    component.destroy()
                    modifierComponents[stackKey] = nil
                end

                return
            end

            if not modifierComponents[stackKey] then
                local newMod = modifierFactory(params :: {[string]: any}) :: any
                modifierComponents[stackKey] = newMod

                local object = instance.getObject()
                if object then
                    newMod.mountTo(object)
                end
            else
                for k, v in pairs(params :: {[string]: any}) do
                    modifierComponents[stackKey].setProperty(k, v)
                end
            end
        end
    end

    instance.setModifier = setModifier

    function instance.getModifier(name: string, index: number?)
        return modifierComponents[`{name}_{index or 1}`]
    end

    instance._addCleanup(function()
        freezeAndClear(modifierComponents)
    end)

    hooks.add("ObjectCreated", function(newObject)
        for _, modifier in pairs(modifierComponents) do
            modifier.mountTo(newObject)
        end
    end)

    hooks.add("OnRedraw", function()
        for _, modifier in pairs(modifierComponents) do
            modifier._redraw()
        end
    end)

    if modifiers then
        for key, modifierProps in pairs(modifiers) do
            -- modifierProps can't be nil... Impossible! MAYBE
            -- (And yea, linter was screaming at me AGAIN)
            setModifier(key, modifierProps :: any)
        end
    end

    return modifierComponents
end
