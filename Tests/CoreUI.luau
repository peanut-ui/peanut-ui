--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Logging = require(ReplicatedStorage.PeanutUI.Utils.Logging)
const Scheduler = require(ReplicatedStorage.PeanutUI.Utils.Scheduler)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)
const Widgets = require(ReplicatedStorage.PeanutUI.Components.Widgets)
const WidgetFeatures = require(ReplicatedStorage.PeanutUI.Classes.WidgetFeatures)

Tests.run("Widget constructors", function()
    const constructors: {() -> any} = {
        function() return Widgets.Frame({}) end,
        function() return Widgets.CanvasGroup({}) end,
        function() return Widgets.ImageLabel({}) end,
        function() return Widgets.ImageButton({}) end,
        function() return Widgets.ScrollingFrame({}) end,
        function() return Widgets.TextLabel({}) end,
        function() return Widgets.TextButton({}) end,
        function() return Widgets.TextBox({}) end,
        function() return Widgets.ViewportFrame({}) end,
        function() return Widgets.VideoFrame({}) end,
    }

    local createdCount = 0
    for _, createWidget in constructors do
        const widget = createWidget()
        if widget.isImplemented("setParent") and widget.isImplemented("getProperty") then
            createdCount += 1
        end
        widget.destroy()
    end
    Tests.expectValue("All public constructors create widgets", createdCount, #constructors)
end)

Tests.run("Widget properties and observers", function()
    Scheduler.stop()
    Tests.finally(function()
        Scheduler.start()
    end)

    const widget = Widgets.Frame({ properties = { name = "Initial" } })
    Tests.expectValue("Initial property is applied", widget.getProperty("name"), "Initial")

    local observedName = ""
    const unobserve = widget.observe("name", function(value: string)
        observedName = value
    end)
    widget.setProperty("name", "Updated")
    Tests.expectValue("Property observer is deferred", observedName, "")
    Scheduler.step()
    Tests.expectValue("Property observer receives update", observedName, "Updated")
    Tests.expectValue("Updated property is readable", widget.getProperty("name"), "Updated")

    unobserve()
    widget.destroy()
end)

Tests.run("Widget feature validation", function()
    const widget = Widgets.Frame({})
    const logger = Logging.getLogger("PeanutUI.Tests.CoreUI")

    WidgetFeatures.requireFeature(logger, widget, "properties")
    WidgetFeatures.requireField(logger, widget, "getObject")
    Tests.expectError("Missing feature is rejected", function()
        WidgetFeatures.requireFeature(logger, widget, "not-a-feature")
    end)
    Tests.expectError("Missing field is rejected", function()
        WidgetFeatures.requireField(logger, widget, "not-a-field")
    end)
    widget.destroy()
end)

return {}