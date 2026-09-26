--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Hooks = require(ReplicatedStorage.PeanutUI.Utils.Hooks)
const Logging = require(ReplicatedStorage.PeanutUI.Utils.Logging)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

Tests.run("Hooks fire in registration order", function()
    const hooks = Hooks.new()
    local received = {}

    hooks.add("change", function(value)
        table.insert(received, `first:{value}`)
    end)
    hooks.add("change", function(value)
        table.insert(received, `second:{value}`)
    end)
    hooks.fire("change", 12)

    Tests.expectDeepEqual("Hook callbacks receive arguments in order", received, { "first:12", "second:12" })
    hooks.clear()
    table.clear(received)
    hooks.fire("change", 13)
    Tests.expectValue("Cleared hooks do not run", #received, 0)
end)

Tests.run("Logging formats and names", function()
    Tests.expectValue("Logger formats string arguments", Logging.resolveMessage("item:%s count:%d", "pen", 3), "item:pen count:3")
    Tests.expectValue("Logger resolves message callback", Logging.resolveMessage(function()
        return "lazy message"
    end), "lazy message")

    const logger = Logging.getLogger("PeanutUI.Tests")
    Tests.expectValue("Logger stores name", logger.name, "PeanutUI.Tests")
    Tests.expectValue("Child logger extends name", logger.getLogger("Child").name, "PeanutUI.Tests.Child")
end)

Tests.run("Logging level can be restored", function()
    const originalLevel = Logging.getLevel()
    Tests.finally(function()
        Logging.setLevel(originalLevel)
    end)

    Logging.setLevel(5)
    Tests.expectValue("Set logging level", Logging.getLevel(), 5)
    Logging.setLevel(2)
    Tests.expectValue("Logging level can change again", Logging.getLevel(), 2)
end)

return {}