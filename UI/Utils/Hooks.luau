--!strict
--!optimize 2
-- For internal logic, much more lightweight compared to Events

const Utils = require(script.Parent.Parent.Types.Utils)

local Hooks = {}

function Hooks.new(): Utils.Hooks
    local listeners: {[string]: {Utils.HooksCallback}} = {}
    local hooks = {}
    hooks._typeName = "hooks"

    function hooks.add(key: string, callback: Utils.HooksCallback)
        if not listeners[key] then
            listeners[key] = {}
        end

        table.insert(listeners[key], callback)
    end

    function hooks.fire(key: string, ...: any)
        local callbacks = listeners[key]
        if not callbacks then
            return
        end

        for _, callback in ipairs(callbacks) do
            callback(...)
        end
    end

    function hooks.clear()
        table.clear(listeners)
    end

    return table.freeze(hooks :: any)
end

return Hooks