--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Box = require(ReplicatedStorage.PeanutUI.Classes.Box)
const Component = require(ReplicatedStorage.PeanutUI.Components.Component)
const Context = require(ReplicatedStorage.PeanutUI.Utils.Context)
const Ref = require(ReplicatedStorage.PeanutUI.Utils.Ref)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)
const Undefined = require(ReplicatedStorage.PeanutUI.Utils.Undefined)

Tests.run("Ref is owned by its bucket", function()
    local ref: any
    const ok, _, bucket = Context.withContext("owner", function()
        ref = Ref.new(1)
        return ref
    end)

    Tests.expectTrue("Context call succeeds", ok)
    assert(bucket)

    ref.value = 2
    Tests.expectValue("Owned ref works before stop", ref.value, 2)

    bucket.stop()
    Tests.expectError("Owned ref is destroyed with bucket", function()
        local _ = ref.value
    end)
end)

Tests.run("Ref created outside a bucket is global", function()
    const ref = Ref.new(10)

    const ok, _, bucket = Context.withContext("unrelated", function()
        return true
    end)
    Tests.expectTrue("Context call succeeds", ok)
    assert(bucket)

    bucket.stop()
    Tests.expectValue("Global ref survives unrelated bucket stop", ref.value, 10)

    ref.value = 11
    Tests.expectValue("Global ref stays writable", ref.value, 11)
end)

Tests.run("Undefined bucket opts out of ownership", function()
    local ref: any
    const ok, _, bucket = Context.withContext("owner", function()
        ref = Ref.new(5, nil, Undefined)
        return ref
    end)

    Tests.expectTrue("Context call succeeds", ok)
    assert(bucket)

    bucket.stop()
    Tests.expectValue("Ref with Undefined bucket survives", ref.value, 5)

    ref.value = 6
    Tests.expectValue("Ref with Undefined bucket stays writable", ref.value, 6)
end)

Tests.run("Watchers are owned by their bucket", function()
    const ref = Ref.new(0)
    local fired = 0

    const ok, _, bucket = Context.withContext("watcherOwner", function()
        ref.watch(function()
            fired += 1
        end, { flush = "sync" })
        return true
    end)

    Tests.expectTrue("Context call succeeds", ok)
    assert(bucket)

    ref.value = 1
    Tests.expectValue("Watcher fires while bucket alive", fired, 1)

    bucket.stop()
    ref.value = 2
    Tests.expectValue("Watcher is removed with bucket", fired, 1)
end)

Tests.run("Explicit watcher bucket overrides current context", function()
    const ref = Ref.new(0)
    local fired = 0

    const owner = Context.createBucket("explicitOwner")
    const ok, _, ambient = Context.withContext("ambient", function()
        ref.watch(function()
            fired += 1
        end, { flush = "sync", bucket = owner })
        return true
    end)

    Tests.expectTrue("Context call succeeds", ok)
    assert(ambient)

    ambient.stop()
    ref.value = 1
    Tests.expectValue("Watcher ignores ambient bucket", fired, 1)

    owner.stop()
    ref.value = 2
    Tests.expectValue("Watcher removed with explicit bucket", fired, 1)
end)

Tests.run("Component owns refs created inside it", function()
    local innerRef: any

    const createWidget = Component.defineComponent(function(_props: {[string]: any})
        innerRef = Ref.new(0)
        return Box.new()
    end)

    const widget = createWidget({})
    innerRef.value = 1
    Tests.expectValue("Component ref works before destroy", innerRef.value, 1)

    widget.destroy()
    Tests.expectError("Component ref is destroyed with component", function()
        local _ = innerRef.value
    end)
end)

Tests.run("Component does not own refs passed through props", function()
    const externalRef = Ref.new(0)

    const createWidget = Component.defineComponent(function(props: {[string]: any})
        props.external.value = props.external.value + 1
        return Box.new()
    end)

    const widget = createWidget({ external = externalRef })
    Tests.expectValue("Prop ref is usable inside component", externalRef.value, 1)

    widget.destroy()
    Tests.expectValue("Prop ref survives component destroy", externalRef.value, 1)

    externalRef.value = 2
    Tests.expectValue("Prop ref stays writable after destroy", externalRef.value, 2)
end)

Tests.run("Widget owns its internal refs", function()
    const widget = Box.new()
    const objectRef = widget.getObjectRef()

    Tests.expectValue("Widget object ref readable before destroy", objectRef.value, nil)

    widget.destroy()
    Tests.expectTrue("Widget is destroyed", widget.isDestroyed())
    Tests.expectError("Widget object ref dies with widget", function()
        local _ = objectRef.value
    end)
end)

Tests.run("Nested buckets stop independently", function()
    local outerRef: any
    local innerRef: any

    const ok, _, outerBucket = Context.withContext("outer", function()
        outerRef = Ref.new(0)

        const innerOk, _, innerBucket = Context.withContext("inner", function()
            innerRef = Ref.new(0)
            return true
        end)
        Tests.expectTrue("Inner context succeeds", innerOk)
        assert(innerBucket)

        innerBucket.stop()
        return true
    end)

    Tests.expectTrue("Outer context succeeds", ok)
    assert(outerBucket)

    Tests.expectError("Inner ref dies with inner bucket", function()
        local _ = innerRef.value
    end)

    outerRef.value = 1
    Tests.expectValue("Outer ref survives inner stop", outerRef.value, 1)

    outerBucket.stop()
    Tests.expectError("Outer ref dies with outer bucket", function()
        local _ = outerRef.value
    end)
end)

Tests.run("Bucket stop is idempotent for owned refs", function()
    local ref: any
    const ok, _, bucket = Context.withContext("owner", function()
        ref = Ref.new(0)
        return true
    end)

    Tests.expectTrue("Context call succeeds", ok)
    assert(bucket)

    bucket.stop()
    bucket.stop()
    Tests.expectError("Ref stays destroyed after repeated stops", function()
        local _ = ref.value
    end)
end)

return {}
