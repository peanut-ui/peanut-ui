--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Box = require(ReplicatedStorage.PeanutUI.Classes.Box)
const ControlFlow = require(ReplicatedStorage.PeanutUI.Components.ControlFlow)
const Ref = require(ReplicatedStorage.PeanutUI.Utils.Ref)
const Scheduler = require(ReplicatedStorage.PeanutUI.Utils.Scheduler)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("For builds one child per entry", function()
    const items = { "a", "b", "c" }
    const seen: {[number]: string} = {}

    const box = ControlFlow.For(items, function(value, index)
        seen[index] = value
        return Box.new()
    end)

    Tests.expectValue("For creates a child per entry", #box.children, 3)
    Tests.expectValue("For passes value and index", seen[1], "a")
    Tests.expectValue("For passes value and index", seen[2], "b")
    Tests.expectValue("For passes value and index", seen[3], "c")

    box.destroy()
end)

Tests.run("For preserves dictionary keys", function()
    const items = { alpha = 1, beta = 2 }
    const seen: {[string]: number} = {}

    const box = ControlFlow.For(items, function(value, key)
        seen[key] = value
        return Box.new()
    end)

    Tests.expectValue("For creates a child per entry", #box.children, 2)
    Tests.expectValue("For passes dictionary key", seen.alpha, 1)
    Tests.expectValue("For passes dictionary key", seen.beta, 2)

    box.destroy()
end)

Tests.run("For is static", function()
    const items = { 1, 2 }
    const box = ControlFlow.For(items, function()
        return Box.new()
    end)

    Tests.expectValue("For starts with two children", #box.children, 2)

    table.insert(items, 3)
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("For ignores later mutations", #box.children, 2)

    box.destroy()
end)

Tests.run("ReactiveFor populates initial entries", function()
    const items = Ref.reactive({ "a", "b" }, true)
    const seen: {[number]: string} = {}

    const box = ControlFlow.ReactiveFor(items, function(value)
        seen[#seen + 1] = value
        return Box.new()
    end, function(value)
        return value
    end)

    Tests.expectValue("ReactiveFor creates a child per entry", #box.children, 2)
    Tests.expectValue("ReactiveFor calls createFn per entry", #seen, 2)

    box.destroy()
end)

Tests.run("ReactiveFor adds new entries", function()
    const items = Ref.reactive({ "a" }, true)

    const box = ControlFlow.ReactiveFor(items, function()
        return Box.new()
    end, function(value)
        return value
    end)

    Tests.expectValue("ReactiveFor starts with one child", #box.children, 1)

    items[2] = "b"
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("ReactiveFor adds a child for new entry", #box.children, 2)

    box.destroy()
end)

Tests.run("ReactiveFor removes missing entries", function()
    const items = Ref.reactive({ "a", "b" }, true)

    const box = ControlFlow.ReactiveFor(items, function()
        return Box.new()
    end, function(value)
        return value
    end)

    Tests.expectValue("ReactiveFor starts with two children", #box.children, 2)

    items[1] = nil
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("ReactiveFor removes a child for missing entry", #box.children, 1)

    box.destroy()
end)

Tests.run("ReactiveFor reuses widgets by key", function()
    const items = Ref.reactive({ "a", "b" }, true)
    local createCount = 0

    const box = ControlFlow.ReactiveFor(items, function()
        createCount += 1
        return Box.new()
    end, function(value)
        return value
    end)

    Tests.expectValue("ReactiveFor creates once per key", createCount, 2)

    items[1] = "b"
    items[2] = "a"
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("ReactiveFor reuses widgets for existing keys", createCount, 2)
    Tests.expectValue("ReactiveFor keeps child count", #box.children, 2)

    box.destroy()
end)

Tests.run("ReactiveFor destroys removed widgets", function()
    const items = Ref.reactive({ "a", "b" }, true)
    const widgets: {[string]: any} = {}

    const box = ControlFlow.ReactiveFor(items, function(value)
        const widget = Box.new()
        widgets[value] = widget
        return widget
    end, function(value)
        return value
    end)

    items[1] = nil
    Scheduler.waitFor("watchers", "after")
    Tests.expectTrue("ReactiveFor destroys removed widget", widgets.a.isDestroyed())
    Tests.expectFalse("ReactiveFor keeps remaining widget", widgets.b.isDestroyed())

    box.destroy()
end)

Tests.run("ReactiveFor errors on plain table", function()
    Tests.expectError("ReactiveFor rejects plain table", function()
        ControlFlow.ReactiveFor({ "a" }, function()
            return Box.new()
        end, function(value)
            return value
        end)
    end)
end)

Tests.run("If reactive branch replacement", function()
    Scheduler.stop()
    Tests.finally(function()
        Scheduler.start()
    end)

    const condition = Ref.new(true)
    local firstCreated = 0
    local secondCreated = 0
    const flow = ControlFlow.If(condition, function()
        firstCreated += 1
        return Box.new()
    end).Else(function()
        secondCreated += 1
        return Box.new()
    end)

    const root = flow.End()
    const firstChild = root.children[1]
    Tests.expectValue("True condition creates first branch", firstCreated, 1)
    Tests.expectValue("Only first branch is mounted", #root.children, 1)

    condition.value = false
    Scheduler.step()

    Tests.expectValue("False condition creates else branch", secondCreated, 1)
    Tests.expectValue("Branch replacement keeps one child", #root.children, 1)
    Tests.expectTrue("Previous branch is destroyed", firstChild.isDestroyed())
    root.destroy()
    condition.destroy()
end)

return {}
