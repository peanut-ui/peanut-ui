--!strict
--!optimize 2
-- Simple defer signal

const Context = require(script.Parent.Context)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)
const Scheduler = require(script.Parent.Scheduler)

local logger = Logging.getLogger("PeanutUI.Utils.Signals")

local SignalsClass = {}

function SignalsClass.new(): Utils.Signals
    local signals = {}
    signals._typeName = "signals"

    local destroyed = false
    local listeners: {[string]: {[Utils.SignalsCallback]: boolean}} = {}

    local scheduledSignals: {[string]: boolean} = {}
    local scheduled = false

    local function fire(signalToFire: string)
        scheduledSignals[signalToFire] = true

        if scheduled then return end
        scheduled = true

        Scheduler.schedule("signals", function()
            scheduled = false

            local scheduled = scheduledSignals
            scheduledSignals = {}

            for signal, _ in scheduled do
                local list = listeners[signal]
                if not list or next(list) == nil then
                    continue
                end

                for callback, _ in pairs(table.clone(list)) do
                    -- Skipping zombies
                    if not listeners[signal] or not listeners[signal][callback] then
                        continue
                    end

                    -- Context manager already got pcall :PP
                    local ok, result = Context.withNoContext(callback :: any)

                    if not ok or result == true then
                        listeners[signal][callback] = nil
                    end
                end
            end
        end)
    end

    local function ensureNotDestroyed()
        if destroyed then
            logger.critical("Tried to access Signals after it was destroyed")
        end
    end

    function signals.listen(signal: string, callback: Utils.SignalsCallback): (() -> ())
        ensureNotDestroyed()

        if not listeners[signal] then
            listeners[signal] = {}
        end

        listeners[signal][callback] = true

        return function()
            if listeners[signal] then
                listeners[signal][callback] = nil
                if #listeners[signal] == 0 then
                    listeners[signal] = nil
                end
            end
        end
    end

    function signals.fire(signal: string)
        ensureNotDestroyed()

        if not listeners[signal] then
            return
        end

        fire(signal)
    end

    function signals.destroy()
        if destroyed then return end
        destroyed = true
        table.clear(listeners)
    end

    return signals
end

return SignalsClass