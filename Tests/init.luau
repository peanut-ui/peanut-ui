--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

return {
    runAll = function()
        Tests.runFunction(function()
            require(script.Scheduler)
            require(script.Refs)
        end)
    end
}