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

Tests.run("Scheduler complicated behavior", function()
    stopSchedulerTemporarily()

    local deferRan = false
    local watchersRan = false
    local createRan = false
    local redrawRan = false

    Scheduler.schedule("watchers", function()
        watchersRan = true

        Scheduler.schedule("create", function()
            createRan = true

            Scheduler.schedule("redraw", function()
                redrawRan = true

                -- Defer has to run on the next tick step
                Scheduler.schedule("defer", function()
                    deferRan = true
                end)
            end)
        end)
    end)

    Tests.expectFalse("Watchers ran on schedule", watchersRan)
    Tests.expectFalse("Create ran on schedule", createRan)
    Tests.expectFalse("Redraw ran on schedule", redrawRan)
    Tests.expectFalse("Defer ran on schedule", deferRan)
    Scheduler.step()

    Tests.expectTrue("Watchers ran on step", watchersRan)
    Tests.expectTrue("Create ran on step", createRan)
    Tests.expectTrue("Redraw ran on step", redrawRan)
    Tests.expectFalse("Defer ran on step", deferRan)
    Scheduler.step()

    Tests.expectTrue("Defer ran on next step", deferRan)
end)

return {}