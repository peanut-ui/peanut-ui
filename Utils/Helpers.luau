--!strict
--!optimize 2
-- Yummy helpers module

const Undefined = require(script.Parent.Undefined)

local Helpers = {}

--- If value is Undefined, it will convert it to nil
function Helpers.removeUndefined<T>(value: T): T
    if value == Undefined then
        return nil
    end

    return value
end

--- Check if value is Undefined or nil
function Helpers.isDefined(v: any): boolean
    return v ~= nil and v ~= Undefined
end

return Helpers