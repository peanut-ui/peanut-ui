--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Scheduler = require(script.Parent.Parent.PeanutUI.Utils.Scheduler)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

local function stopSchedulerTemporarily()
    Scheduler.stop()
    Tests.finally(function()
        Scheduler.start()
    end)
end

Tests.run("Scheduler phase order", function()
    stopSchedulerTemporarily()

    local order = {}

    Scheduler.scheduleBefore("redraw", function()
        table.insert(order, "before")
    end)
    Scheduler.schedule("redraw", function()
        table.insert(order, "schedule")
    end)
    Scheduler.scheduleAfter("redraw", function()
        table.insert(order, "after")
    end)

    Scheduler.step()

    Tests.expectDeepEqual("Phase order", order, { "before", "schedule", "after" })
    Tests.expectValue("Stage reset", Scheduler.getCurrentStage(), "sync")
    Tests.expectValue("Phase reset", Scheduler.getCurrentStagePhase(), "sync")
end)

Tests.run("Scheduler stage order", function()
    stopSchedulerTemporarily()

    local order = {}
    local stages: {"defer" | "watchers" | "create" | "signals" | "redraw" | "settled"} = {
        "defer",
        "watchers",
        "create",
        "signals",
        "redraw",
        "settled"
    }

    for _, stage in stages do
        Scheduler.schedule(stage, function()
            table.insert(order, stage)
        end)
    end

    Scheduler.step()

    Tests.expectDeepEqual("Stage order", order, stages)
end)

Tests.run("Scheduler watcher drain", function()
    stopSchedulerTemporarily()

    local order = {}

    Scheduler.schedule("watchers", function()
        table.insert(order, "first")
        Scheduler.schedule("watchers", function()
            table.insert(order, "second")
        end)
    end)

    Scheduler.step()

    Tests.expectDeepEqual("Drained watchers", order, { "first", "second" })
end)

Tests.run("Scheduler waitFor", function()
    local resumed = false

    task.spawn(function()
        Scheduler.waitFor("watchers", "before")
        resumed = true
    end)

    Tests.expectFalse("waitFor yields", resumed)

    Scheduler.waitFor("watchers")
    Tests.expectTrue("waitFor resumes", resumed)
end)

return {}