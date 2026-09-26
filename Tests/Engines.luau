--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Animation = require(ReplicatedStorage.PeanutUI.Engines.Animation)
const Curves = require(ReplicatedStorage.PeanutUI.Math.Curves)
const Ease = require(ReplicatedStorage.PeanutUI.Engines.Ease)
const Spring = require(ReplicatedStorage.PeanutUI.Engines.Spring)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("Animation start pause continue and stop", function()
    const object = Instance.new("Folder")
    local function step(_object: Instance, _deltaTime: number, _state: any): boolean
        return false
    end

    Animation.start(object, step, { value = 3 })
    Tests.expectTrue("Started animation is active", Animation.isAnimating(object, step))
    Tests.expectTrue("Started animation is running", Animation.isRunning(object, step))

    Animation.pause(object, step)
    Tests.expectFalse("Paused animation is not running", Animation.isRunning(object, step))
    Animation.continue(object, step)
    Tests.expectTrue("Continued animation is running", Animation.isRunning(object, step))

    Animation.stop(object, step)
    Tests.expectFalse("Stopped animation is inactive", Animation.isAnimating(object, step))
    object:Destroy()
end)

Tests.run("Ease target stop and immediate update", function()
    const object = Instance.new("NumberValue")
    object.Value = 2

    Ease.target(object, "Value", 10, 1, Curves.Linear)
    Tests.expectTrue("Ease target starts animation", Ease.isAnimating(object, "Value"))
    Tests.expectTrue("Ease reports object animation", Ease.isAnimating(object))

    Ease.stop(object, "Value")
    Tests.expectFalse("Ease property stop clears animation", Ease.isAnimating(object, "Value"))
    Tests.expectFalse("Ease property stop clears empty object state", Ease.isAnimating(object))

    Ease.target(object, "Value", 20, 0, Curves.Linear)
    Tests.expectValue("Zero-duration ease applies target", object.Value, 20)
    Tests.expectFalse("Zero-duration ease leaves no active state", Ease.isAnimating(object))
    object:Destroy()
end)

Tests.run("Spring target stop and immediate update", function()
    const object = Instance.new("NumberValue")
    object.Value = 2

    Spring.target(object, 1, 2, { Value = 10 })
    Tests.expectTrue("Spring target starts animation", Spring.isAnimating(object, "Value"))
    Spring.stop(object, "Value")
    Tests.expectFalse("Spring property stop clears animation", Spring.isAnimating(object, "Value"))

    Spring.target(object, 1, math.huge, { Value = 20 })
    Tests.expectValue("Infinite-frequency spring applies target", object.Value, 20)
    Tests.expectFalse("Immediate spring leaves no active state", Spring.isAnimating(object, "Value"))
    object:Destroy()
end)

return {}