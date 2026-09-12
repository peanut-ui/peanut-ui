--!strict
--!optimize 2
const ComponentContext = require(script.Parent.ComponentContext)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)

local logger = Logging.getLogger("PeanutUI.Utils.Events")

local EventsClass = {}

function EventsClass.new(): Utils.Events
    local events = {}
    events._typeName = "events"

    local destroyed = false
    local listeners: Utils.EventsListeners = {}
    events.listeners = listeners

    local function ensureNotDestroyed()
        if destroyed then
            logger.critical("Tried to access Events after it was destroyed")
        end
    end

    function events.listen(event: string, callback: Utils.EventsCallback): (() -> ())
        ensureNotDestroyed()

        if not listeners[event] then
            listeners[event] = {}
        end

        listeners[event][callback] = true

        return function()
            if listeners[event] then
                listeners[event][callback] = nil
                if #listeners[event] == 0 then
                    listeners[event] = nil
                end
            end
        end
    end

    function events.fire(event: string, ...)
        ensureNotDestroyed()

        local list = listeners[event]
        if not list or next(list) == nil then
            return
        end

        for callback, _ in pairs(table.clone(list)) do
            -- No zombies!!!
            if not listeners[event] or not listeners[event][callback] then
                continue
            end

            -- Context manager already got pcall >_<
            local ok, result = ComponentContext.withNoContext(callback :: any)

            if not ok or result == true then
                listeners[event][callback] = nil
            end
        end
    end

    function events.destroy()
        if destroyed then return end
        destroyed = true
        table.clear(listeners)
    end

    return events
end

return EventsClass