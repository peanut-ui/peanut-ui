--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Box = require(ReplicatedStorage.PeanutUI.Classes.Box)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("Box parenting and child events", function()
    const parent = Box.new()
    const child = Box.new()
    local addedChild: any = nil
    local removedChild: any = nil

    parent.listen("ChildAdded", function(value)
        addedChild = value
    end)
    parent.listen("ChildRemoved", function(value)
        removedChild = value
    end)

    child.setParent(parent)
    Tests.expectValue("Set parent updates parent reference", child.getParent(), parent)
    Tests.expectValue("Set parent adds child", parent.children[1], child)
    Tests.expectValue("Parent emits ChildAdded", addedChild, child)

    parent.removeChild(child)
    Tests.expectValue("Clear parent updates parent reference", child.getParent(), nil)
    Tests.expectValue("Clear parent removes child", #parent.children, 0)
    Tests.expectValue("Parent emits ChildRemoved", removedChild, child)

    child.destroy()
    parent.destroy()
end)

Tests.run("Box destroy clears descendants", function()
    const parent = Box.new()
    const child = Box.new()
    local destroyingCount = 0
    child.listen("Destroying", function()
        destroyingCount += 1
    end)

    child.setParent(parent)
    parent.destroy()
    parent.destroy()

    Tests.expectTrue("Parent destroy is idempotent", parent.isDestroyed())
    Tests.expectTrue("Parent destroys its child", child.isDestroyed())
    Tests.expectValue("Child emits Destroying once", destroyingCount, 1)
    Tests.expectValue("Parent releases child list", #parent.children, 0)
    Tests.expectError("Destroyed box rejects new listeners", function()
        parent.listen("Hello", function() end)
    end)
end)

Tests.run("Box clearChildren destroys children", function()
    const parent = Box.new()
    const first = Box.new()
    const second = Box.new()
    first.setParent(parent)
    second.setParent(parent)

    parent.clearChildren()
    Tests.expectValue("clearChildren empties list", #parent.children, 0)
    Tests.expectTrue("clearChildren destroys first child", first.isDestroyed())
    Tests.expectTrue("clearChildren destroys second child", second.isDestroyed())
    parent.destroy()
end)

return {}