--!strict
--!optimize 2
-- Yummy helpers module

const Undefined = require(script.Parent.Undefined)

local Helpers = {}

--- If value is Undefined, it will convert it to nil
function Helpers.removeUndefined<T>(value: T): T
    if value == Undefined then
        return nil :: T
    end

    return value
end

--- Check if value is Undefined or nil
function Helpers.isDefined(v: any): boolean
    return v ~= nil and v ~= Undefined
end

local function isWidget(obj: any)
    if typeof(obj) ~= "table" then
        return false
    end

    if obj._widgetLike == true then
        return true
    end

    if not obj._typeName or obj._typeName ~= "widget" then
        return false
    end

    return true
end
Helpers.isWidget = isWidget

function Helpers.widgetsAreSame(a: any, b: any)
    if not isWidget(a) or not isWidget(b) then
        return false
    end

    return a._uniqueId == b._uniqueId
end

function Helpers.freezeAndClear(tbl: {[any]: any}?)
    if type(tbl) ~= "table" then
        return
    end

    table.clear(tbl)
    table.freeze(tbl)
end

function Helpers.readonly<T>(original: T): T
	local proxy = {}

	setmetatable(proxy, {
		__index = original,

		__newindex = function()
			error("attempt to modify read-only table", 2)
		end,

        __iter = function()
            return next, original, nil
        end,

		__metatable = false,
	})

	return proxy :: T
end

return table.freeze(Helpers)