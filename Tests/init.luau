--!strict
--!optimize 2
const Tests = require(script.Parent.PeanutUI.Utils.Tests)

return {
    runAll = function()
        Tests.runFunction(function()
            require(script.Scheduler)
            require(script.Refs)
        end)
    end
}