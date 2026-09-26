--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Box = require(ReplicatedStorage.PeanutUI.Classes.Box)
const Component = require(ReplicatedStorage.PeanutUI.Components.Component)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("Component lifecycle hooks", function()
    local setupCount = 0
    local beforeDestroyedCount = 0
    local destroyedCount = 0

    const createWidget = Component.defineComponent(function(_props: {[string]: any})
        Component.onSetup(function(widget)
            if widget then
                setupCount += 1
            end
        end)
        Component.onBeforeDestroyed(function()
            beforeDestroyedCount += 1
        end)
        Component.onDestroyed(function()
            destroyedCount += 1
        end)
        return Box.new()
    end)

    const widget = createWidget({})
    Tests.expectValue("Setup hook runs once", setupCount, 1)
    Tests.expectValue("Destroy hooks wait for destruction", beforeDestroyedCount + destroyedCount, 0)

    widget.destroy()
    Tests.expectValue("Before-destroy hook runs once", beforeDestroyedCount, 1)
    Tests.expectValue("Destroyed hook runs once", destroyedCount, 1)
end)

return {}