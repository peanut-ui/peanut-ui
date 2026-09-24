--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Logging = require(script.Parent.Parent.PeanutUI.Utils.Logging)
const Scheduler = require(script.Parent.Parent.PeanutUI.Utils.Scheduler)
const Ref = require(ReplicatedStorage.PeanutUI.Utils.Ref)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Logging.setLevel(4)

Tests.run("Seed & store", function()
    const r = Ref.new(10)
    Tests.expectValue("seed", r.value, 10)

    r.value = 25
    Tests.expectValue("after update", r.value, 25)

    Tests.expectTrue("is a ref", Ref.isRef(r))
    Tests.expectFalse("plain value is not a ref", Ref.isRef(10))
end)

Tests.run("Watch & release", function()
    const r = Ref.new("hello")
    local receivedValue = ""

    const unwatch = r.watch(function(val)
        receivedValue = val
    end, nil, true)

    r.value = "world"
    Tests.expectValue("watch saw update", receivedValue, "world")

    unwatch()
    r.value = "test"
    Tests.expectValue("watch stopped", receivedValue, "world")
end)

Tests.run("Once only", function()
    const r = Ref.new(1)
    local count = 0

    r.watch(function(val)
        count += 1
        return true
    end, nil, true)

    r.value = 2
    r.value = 3
    Tests.expectValue("one fire", count, 1)
end)

Tests.run("Transform", function()
    const count = Ref.new(5)
    const strRef = Ref.transform(count, function(val: number)
        return tostring(val * 2)
    end)

    Tests.expectValue("transform start", strRef.value, "10")

    count.value = 8
    Tests.expectValue("transform after change", strRef.value, "16")
end)

Tests.run("Computed", function()
    const x = Ref.new(3)
    const y = Ref.new(4)

    const computedSum = Ref.computed(function()
        return x.value + y.value
    end)

    Tests.expectValue("base sum", computedSum.value, 7)

    x.value = 10
    Tests.expectValue("sum after update", computedSum.value, 14)
end)

Tests.run("Loop guard", function()
    local loopRef: any
    loopRef = Ref.computed(function()
        return loopRef.value + 1
    end)

    Tests.expectError("catches self-loop", function()
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
    Tests.expectValue("field ref matches", scoreRef.value, 200)
end)

Tests.run("Swap", function()
    const proxy = Ref.reactive({ value = 10, nested = { x = 1 } })

    Ref.swap(proxy, { value = 50, nested = { x = 1 } })
    Tests.expectValue("Shallow swap", proxy.value, 50)

    Ref.deepSwap(proxy, { value = 50, nested = { x = 99 } })
    Tests.expectValue("Deep swap", proxy.nested.x, 99)
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

return {}