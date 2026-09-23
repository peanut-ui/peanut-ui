--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Logging = require(script.Parent.Parent.PeanutUI.Utils.Logging)
const Ref = require(ReplicatedStorage.PeanutUI.Utils.Ref)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Logging.setLevel(4)

Tests.run("Ref.new & basic value access", function()
    const r = Ref.new(10)
    Tests.expectValue("Initial value", r.value, 10)

    r.value = 25
    Tests.expectValue("Updated value", r.value, 25)

    Tests.expectTrue("Is Ref object", Ref.isRef(r))
    Tests.expectFalse("Is not Ref (primitive)", Ref.isRef(10))
end)

Tests.run("Ref watchers and unwatching", function()
    const r = Ref.new("hello")
    local receivedValue = ""

    const unwatch = r.watch(function(val)
        receivedValue = val
    end, nil, true)

    r.value = "world"
    Tests.expectValue("Watcher received updated value", receivedValue, "world")

    unwatch()
    r.value = "test"
    Tests.expectValue("Watcher stopped after unwatch", receivedValue, "world")
end)

Tests.run("Ref 'once' watcher (returning true)", function()
    const r = Ref.new(1)
    local count = 0

    r.watch(function(val)
        count += 1
        return true
    end, nil, true)

    r.value = 2
    r.value = 3
    Tests.expectValue("Once watcher only fired once", count, 1)
end)

Tests.run("Ref.transform", function()
    const count = Ref.new(5)
    const strRef = Ref.transform(count, function(val: number)
        return tostring(val * 2)
    end)

    Tests.expectValue("Initial transformed value", strRef.value, "10")

    count.value = 8
    Tests.expectValue("Transformed value updates on source change", strRef.value, "16")
end)

Tests.run("Ref.computed basic & evaluation", function()
    const x = Ref.new(3)
    const y = Ref.new(4)

    const computedSum = Ref.computed(function()
        return x.value + y.value
    end)

    Tests.expectValue("Computed initial sum", computedSum.value, 7)

    x.value = 10
    Tests.expectValue("Computed sum updates after dependency change", computedSum.value, 14)
end)

Tests.run("Ref.computed circular dependency check", function()
    local loopRef: any
    loopRef = Ref.computed(function()
        return loopRef.value + 1
    end)

    Tests.expectError("Computed throws error on circular dependency", function()
        local _ = loopRef.value
    end)
end)

Tests.run("Ref.reactive, toRaw, getRef, and toRef", function()
    const raw = { score = 100, name = "Player" }
    const proxy = Ref.reactive(raw)

    Tests.expectValue("Proxy reflects raw value", proxy.score, 100)

    proxy.score = 200
    Tests.expectValue("Proxy mutation updates value", proxy.score, 200)

    const rawUnwrapped = Ref.toRaw(proxy)
    Tests.expectTrue("Ref.toRaw returns table", type(rawUnwrapped) == "table")

    const proxyRef = Ref.getRef(proxy)
    Tests.expectTrue("Ref.getRef returns a valid ref", Ref.isRef(proxyRef))

    const scoreRef = Ref.toRef(proxy, "score")
    Tests.expectTrue("Ref.toRef returns a valid ref for key", Ref.isRef(scoreRef))
    Tests.expectValue("Ref.toRef value matches proxy field", scoreRef.value, 200)
end)

Tests.run("Ref.swap and Ref.deepSwap", function()
    const proxy = Ref.reactive({ value = 10, nested = { x = 1 } })

    Ref.swap(proxy, { value = 50, nested = { x = 1 } })
    Tests.expectValue("Swap updates top-level value", proxy.value, 50)

    Ref.deepSwap(proxy, { value = 50, nested = { x = 99 } })
    Tests.expectValue("DeepSwap updates nested value", proxy.nested.x, 99)
end)

return {}