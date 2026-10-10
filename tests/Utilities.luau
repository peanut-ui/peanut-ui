--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Context = require(ReplicatedStorage.PeanutUI.Utils.Context)
const Events = require(ReplicatedStorage.PeanutUI.Utils.Events)
const Helpers = require(ReplicatedStorage.PeanutUI.Utils.Helpers)
const Scheduler = require(ReplicatedStorage.PeanutUI.Utils.Scheduler)
const Signals = require(ReplicatedStorage.PeanutUI.Utils.Signals)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)
const Undefined = require(ReplicatedStorage.PeanutUI.Utils.Undefined)
const Units = require(ReplicatedStorage.PeanutUI.Utils.Units)

local function stopSchedulerTemporarily()
    Scheduler.stop()
    Tests.finally(function()
        Scheduler.start()
    end)
end

Tests.run("Events listeners and payloads", function()
    const events = Events.new()
    local receivedValue = 0
    const unlisten = events.listen("Changed", function(value)
        receivedValue = value
    end)

    events.fire("Changed", 42)
    Tests.expectValue("Event forwards payload", receivedValue, 42)

    unlisten()
    events.fire("Changed", 100)
    Tests.expectValue("Unlisten prevents callback", receivedValue, 42)
    events.destroy()
end)

Tests.run("Events once and listener removal", function()
    const events = Events.new()
    local onceCount = 0
    events.listen("Tick", function()
        onceCount += 1
        return true
    end)

    events.fire("Tick")
    events.fire("Tick")
    Tests.expectValue("Once listener fires once", onceCount, 1)

    local removedCount = 0
    const unlisten = events.listen("Removed", function()
        removedCount += 1
    end)
    unlisten()
    events.fire("Removed")
    Tests.expectValue("Removed listener is skipped", removedCount, 0)
    events.destroy()
end)

Tests.run("Signals defer and coalesce", function()
    stopSchedulerTemporarily()

    const signals = Signals.new()
    local firedCount = 0
    signals.listen("Changed", function()
        firedCount += 1
    end)

    signals.fire("Changed")
    signals.fire("Changed")
    Tests.expectValue("Signal waits for scheduler", firedCount, 0)

    Scheduler.step()
    Tests.expectValue("Repeated fires coalesce", firedCount, 1)
    signals.destroy()
end)

Tests.run("Signals unlisten", function()
    stopSchedulerTemporarily()

    const signals = Signals.new()
    local firedCount = 0
    const unlisten = signals.listen("Changed", function()
        firedCount += 1
    end)

    unlisten()
    signals.fire("Changed")
    Scheduler.step()
    Tests.expectValue("Unlistened signal is skipped", firedCount, 0)
    signals.destroy()
end)

Tests.run("Units conversion", function()
    const size = Units.Size(12, 34, 0.25, 0.75)
    const sizeUDim2 = Units.ToUDim2(size)
    Tests.expectValue("Size converts to UDim2", sizeUDim2, UDim2.new(0.25, 12, 0.75, 34))
    Tests.expectDeepEqual("Size converts back", Units.SizeFromUDim2(sizeUDim2), size)

    const position = Units.Position(5, 9, 0.1, 0.2)
    const positionUDim2 = Units.ToUDim2(position)
    Tests.expectValue("Position converts to UDim2", positionUDim2, UDim2.new(0.1, 5, 0.2, 9))

    local originalPosition = Units.PositionFromUDim2(positionUDim2)
    Tests.expectValue( "Position converts back", Units.ToUDim2(originalPosition), positionUDim2)

    const unit = Units.Unit(7, 0.5)
    const udim = Units.ToUDim(unit)
    Tests.expectValue("Unit converts to UDim", udim, UDim.new(0.5, 7))
    Tests.expectDeepEqual("Unit converts back", Units.UnitFromUDim(udim), unit)
    Tests.expectValue("UDim2 passes through", Units.ToUDim2(sizeUDim2), sizeUDim2)
    Tests.expectValue("UDim passes through", Units.ToUDim(udim), udim)
end)

Tests.run("Helpers defined and widgets", function()
    Tests.expectTrue("Ordinary value is defined", Helpers.isDefined(0))
    Tests.expectFalse("Nil is not defined", Helpers.isDefined(nil))
    Tests.expectFalse("Undefined sentinel is not defined", Helpers.isDefined(Undefined))
    Tests.expectValue("Undefined is removed", Helpers.removeUndefined(Undefined), nil)

    const widgetA = { _widgetLike = true, _uniqueId = 1 }
    const widgetSameId = { _typeName = "widget", _uniqueId = 1 }
    const widgetOtherId = { _widgetLike = true, _uniqueId = 2 }
    Tests.expectTrue("Widget-like table is a widget", Helpers.isWidget(widgetA))
    Tests.expectTrue("Widget tables with same id match", Helpers.widgetsAreSame(widgetA, widgetSameId))
    Tests.expectFalse("Different widget ids do not match", Helpers.widgetsAreSame(widgetA, widgetOtherId))
    Tests.expectFalse("Plain tables are not widgets", Helpers.isWidget({}))
end)

Tests.run("Helpers readonly and freeze", function()
    const original = { value = 10, other = 20 }
    const readonly: any = Helpers.readonly(original)
    Tests.expectValue("Readonly proxy reads original", readonly.value, 10)
    Tests.expectError("Readonly proxy rejects writes", function()
        readonly.value = 15
    end)

    local iteratedCount = 0
    for _ in readonly do
        iteratedCount += 1
    end
    Tests.expectValue("Readonly proxy iterates all keys", iteratedCount, 2)

    const cleared = { value = true }
    Helpers.freezeAndClear(cleared)
    Tests.expectValue("freezeAndClear removes entries", next(cleared), nil)
    Tests.expectTrue("freezeAndClear freezes table", table.isfrozen(cleared))
    Helpers.freezeAndClear(nil)
end)

Tests.run("Context stack and cleanup", function()
    Tests.expectValue("No context before call", Context.getCurrentBucket(), nil)

    local cleanupCount = 0
    local wasInContext = false
    const ok, result, bucket = Context.withContext("test", function()
        const current = Context.getCurrentBucket()
        wasInContext = current ~= nil and current.contextName == "test"
        if current then
            current.addCleanup(function()
                cleanupCount += 1
            end)
        end
        return "value"
    end)

    Tests.expectTrue("Context call succeeds", ok)
    Tests.expectValue("Context returns result", result, "value")
    Tests.expectTrue("Context is available in callback", wasInContext)
    Tests.expectValue("Context restores stack", Context.getCurrentBucket(), nil)
    assert(bucket)
    bucket.stop()
    Tests.expectValue("Bucket runs cleanup", cleanupCount, 1)
    bucket.stop()
    Tests.expectValue("Bucket cleanup is idempotent", cleanupCount, 1)
end)

Tests.run("Context suppresses and restores", function()
    local sawNoContext = false
    const ok = Context.withContext("outer", function()
        const outer = Context.getCurrentBucket()
        const innerOk = Context.withNoContext(function()
            sawNoContext = Context.getCurrentBucket() == nil
            return true
        end)
        Tests.expectTrue("No-context callback succeeds", innerOk)
        Tests.expectValue("Outer context restored", Context.getCurrentBucket(), outer)
        return true
    end)

    Tests.expectTrue("Context callback succeeds", ok)
    Tests.expectTrue("No-context marker hides bucket", sawNoContext)
    Tests.expectValue("Context stack empty after return", Context.getCurrentBucket(), nil)
end)

return {}