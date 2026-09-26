--!strict
--!optimize 2
-- Yummy helpers module

const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)
const Utils = require(script.Parent.Parent.Types.Utils)
const Undefined = require(script.Parent.Undefined)

local Helpers = {}
type Defined<T> = T & TypeFuncs.Negate<nil | Utils.Undefined>

--- Asserts if type is defined
function Helpers.requireDefined<T>(value: T): Defined<T>
    assert(value ~= nil and value ~= Undefined)
    return value :: Defined<T>
end

--- If value is Undefined, it will convert it to nil
function Helpers.removeUndefined<T>(value: T): T & TypeFuncs.Negate<Utils.Undefined>
    if value == Undefined then
        return nil :: T
    end

    return value
end

--- Check if value is Undefined or nil
function Helpers.isDefined(v: any): boolean
    return v ~= nil and v ~= Undefined
end

--- Checks if object is widget or *widget like*
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

--- Checks if widgets are the same (checks their _uniqueId)
function Helpers.widgetsAreSame(a: any, b: any)
    if not isWidget(a) or not isWidget(b) then
        return false
    end

    return a._uniqueId == b._uniqueId
end

--- Freeze and clear table, useful in cleanups
function Helpers.freezeAndClear(tbl: {[any]: any}?)
    if type(tbl) ~= "table" then
        return
    end

    table.clear(tbl)
    table.freeze(tbl)
end

--- Makes readonly proxy
function Helpers.readonly<T>(original: T & {[any]: any}): T
	local proxy = {}

	setmetatable(proxy, {
		__index = original,

		__newindex = function()
			error("attempt to modify read-only table", 2)
		end,

        __iter = function()
            return next, original, nil
        end,
        __len = function(): number
            return #original
        end,

		__metatable = false,
	})

	return proxy :: T
end

--- Runs function and checks if it yielded, if it did then closes coroutine and errors
function Helpers.disableYielding<R, A...>(fn: (A...) -> R, ...: A...): (boolean, R?)
    local thread = coroutine.create(fn)

    local ok, result = coroutine.resume(thread, ...)

    if not ok then
        local errorTrace = debug.traceback(thread, tostring(result))
        return false, errorTrace
    end

    if coroutine.status(thread) ~= "dead" then
        local trace = debug.traceback(thread)
        coroutine.close(thread)

        return false, `Cannot yield in current context.\nHINT: check for tags: yield in method's description\nTraceback: {trace}`
    end

    return true, result
end

return table.freeze(Helpers)