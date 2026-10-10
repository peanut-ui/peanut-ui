--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Scheduler = require(script.Parent.Parent.PeanutUI.Utils.Scheduler)
const Ref = require(ReplicatedStorage.PeanutUI.Utils.Ref)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("Seed & store", function()
    const r = Ref.new(10)
    Tests.expectValue("Seed", r.value, 10)

    r.value = 25
    Tests.expectValue("After update", r.value, 25)

    Tests.expectTrue("Is a ref", Ref.isRef(r))
    Tests.expectFalse("Plain value is not a ref", Ref.isRef(10))
    Tests.expectFalse("Table value is not a ref", Ref.isRef({}))
end)

Tests.run("Watch & release", function()
    const r = Ref.new("hello")
    local receivedValue = ""

    const unwatch = r.watch(function(val)
        receivedValue = val
    end, { flush = "sync" })

    r.value = "world"
    Tests.expectValue("Watch saw update", receivedValue, "world")

    unwatch()
    r.value = "test"
    Tests.expectValue("Watch stopped", receivedValue, "world")
end)

Tests.run("Once only", function()
    const r = Ref.new(1)
    local count = 0

    r.watch(function(val)
        count += 1
        return true
    end, { flush = "sync" })

    r.value = 2
    r.value = 3
    Tests.expectValue("One fire", count, 1)
end)

Tests.run("Computed", function()
    const x = Ref.new(3)
    const y = Ref.new(4)

    const computedSum = Ref.computed(function()
        return x.value + y.value
    end)

    Tests.expectValue("Base sum", computedSum.value, 7)

    x.value = 10
    Tests.expectValue("Sum after update", computedSum.value, 14)
end)

Tests.run("Loop guard", function()
    local loopRef: any
    loopRef = Ref.computed(function()
        return loopRef.value + 1
    end)

    Tests.expectError("Catches self-loop", function()
        local _ = loopRef.value
    end)
end)

Tests.run("Reactive proxy", function()
    const raw = { score = 100, name = "Player" }
    const proxy = Ref.reactive(raw)

    Tests.expectValue("Proxy read", proxy.score, 100)

    proxy.score = 200
    Tests.expectValue("Proxy update", proxy.score, 200)

    const rawUnwrapped = Ref.toRaw(proxy)
    Tests.expectTrue("toRaw gives table", type(rawUnwrapped) == "table")

    const proxyRef = Ref.getRef(proxy)
    Tests.expectTrue("getRef returns ref", Ref.isRef(proxyRef))

    const scoreRef = Ref.toRef(proxy, "score")
    Tests.expectTrue("toRef returns field ref", Ref.isRef(scoreRef))
    Tests.expectValue("Field ref matches", scoreRef.value, 200)
end)

Tests.run("Scheduled watch", function()
    const ref = Ref.new(0)
    local triggered = 0

    ref.watch(function()
        triggered += 1
    end)

    Tests.expectValue("Watch doesn't trigger on init", triggered, 0)

    ref.value += 1
    Tests.expectValue("Watch doesn't trigger in the same tick", triggered, 0)

    ref.value += 1
    ref.value += 1
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("Watch triggered only once", triggered, 1)
end)

Tests.run("Complicated computed behavior", function()
    const a = Ref.new(0)

    const b = Ref.computed(function()
        return a.value * 2
    end)
    const c = Ref.computed(function()
        return a.value * 3
    end)

    local computedTimes = 0
    const d = Ref.computed(function()
        computedTimes += 1
        return a.value * 3 + b.value + c.value
    end)

    Tests.expectValue("Lazy compute", computedTimes, 0)

    d.getValue()
    Tests.expectValue("Compute once on get", computedTimes, 1)

    a.value += 1
    Tests.expectValue("Lazy compute on dependency change", computedTimes, 1)

    d.getValue()
    Tests.expectValue("Compute once on get when dirty", computedTimes, 2)

    local watcherGotValue = -1
    a.value += 1
    d.watch(function(value)
        watcherGotValue = value
    end)
    Tests.expectValue("Compute once on watch when dirty", computedTimes, 3)

    a.value += 1
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("Auto compute when there's a watcher", computedTimes, 4)
    Tests.expectValue("Watcher got last value", watcherGotValue, d.value)
end)

Tests.run("Computed diamond shape", function()
    const a = Ref.new(0)

    const b = Ref.computed(function()
        return a.value * 2
    end)
    const c = Ref.computed(function()
        return a.value * 3
    end)

    local computedTimes = 0
    const d = Ref.computed(function()
        computedTimes += 1
        return b.value + c.value
    end)

    Tests.expectValue("Lazy compute", computedTimes, 0)

    d.getValue()
    Tests.expectValue("Compute once on get", computedTimes, 1)

    a.value += 1
    Tests.expectValue("Lazy compute on dependency change", computedTimes, 1)

    d.getValue()
    Tests.expectValue("Compute once on get when dirty", computedTimes, 2)

    local watcherGotValue = -1
    a.value += 1
    d.watch(function(value)
        watcherGotValue = value
    end)
    Tests.expectValue("Compute once on watch when dirty", computedTimes, 3)

    a.value += 1
    Scheduler.waitFor("watchers", "after")
    Tests.expectValue("Auto compute when there's a watcher", computedTimes, 4)
    Tests.expectValue("Watcher got last value", watcherGotValue, d.value)
end)

Tests.run("Side-effects error", function()
    const a = Ref.new(0)

    const b = Ref.computed(function()
        a.setValue(12)
        return a.value
    end)

    a.value = 1
    Tests.expectError("Error on read", function()
        b.getValue()
    end)
end)

return {}