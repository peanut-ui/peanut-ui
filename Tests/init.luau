--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

return {
    runAll = function()
        Tests.runFunction(function()
            require(script.Scheduler)
            require(script.Refs)
            require(script.Utilities)
            require(script.HooksAndLogging)
            require(script.Math)
            require(script.Boxes)
            require(script.Engines)
            require(script.Components)
            require(script.CoreUI)
        end)
    end
}