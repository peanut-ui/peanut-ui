--!strict
--!optimize 2

export type Instance = {
    read name: string,
    read debug: (string | () -> string, ...any) -> (),
    read info: (string | () -> string, ...any) -> (),
    read warn: (string | () -> string, ...any) -> (),
    read error: (string | () -> string, ...any) -> ...unknown,
    read critical: (string | () -> string, ...any) -> ...unknown,
    read getLogger: (string) -> Instance
}

--[[
    1 -> debug
    2 -> info
    3 -> warn
    4 -> error
    5 -> critical
]]
local level = 2
local Logger = {}

--- Resolves `formatOrFn` object, pass `...` to automatically format string using `string.format`
---
--- `...` doesn't format if `formatOrFn` is a function
local function resolveMessage(formatOrFn: string | () -> string, ...: any): string
    if typeof(formatOrFn) == "function" then
        local ok, result = pcall(formatOrFn)
        if not ok then
            return `(message callback failed: {tostring(result)})`
        end
        return result
    end

    local argCount = select("#", ...)
    if argCount == 0 then
        return formatOrFn
    end

    local args = table.pack(...)
    for index = 1, argCount do
        local value = args[index]
        local valueType = typeof(value)
        if valueType ~= "number" and valueType ~= "string" then
            args[index] = tostring(value)
        end
    end

    local ok, result = pcall(string.format, formatOrFn, table.unpack(args, 1, argCount))
    if not ok then
        return `{formatOrFn} (format failed: {tostring(result)})`
    end

    return result
end

local function log(name: string, formatOrFn: string | () -> string, logLevel: number, ...: any)
    local message = resolveMessage(formatOrFn, ...)

    if logLevel == 1 then
        print(`[DEBUG] [{name}] {message}`)
    elseif logLevel == 2 then
        print(`[INFO] [{name}] {message}`)
    elseif logLevel == 3 then
        warn(`[WARNING] [{name}] {message}\n[TRACEBACK] {debug.traceback(nil, 3)}`)
    elseif logLevel == 4 then
        error(`[ERROR] [{name}] {message}\n[TRACEBACK] {debug.traceback(nil, 3)}`)
    elseif logLevel == 5 then
        error(`[CRITICAL] [{name}] {message}\n[TRACEBACK] {debug.traceback(nil, 3)}`)
    end
end

--- Creates logger instance to log
---
--- logger.error and logger.critical always errors and stops execution of code
---
--- @param name Name that is used for formatting
--- @return Logger instance
function Logger.getLogger(name: string, logLevel: number?): Instance
    local logger = {}
    logger.name = name

    function logger.debug(string: string | () -> string, ...): ()
        if 1 < (logLevel or level) then
            return
        end

        log(name, string, 1, ...)
    end

    function logger.info(string: string | () -> string, ...): ()
        if 2 < (logLevel or level) then
            return
        end

        log(name, string, 2, ...)
    end

    function logger.warn(string: string | () -> string, ...): ()
        if 3 < (logLevel or level) then
            return
        end

        log(name, string, 3, ...)
    end

    function logger.error(string: string | () -> string, ...)
        log(name, string, 4, ...)
        error(resolveMessage(string, ...))  -- In case log doesn't stop execution
    end

    function logger.critical(string: string | () -> string, ...)
        log(name, string, 5, ...)
        error(resolveMessage(string, ...))  -- Same as in logger.error
    end

    function logger.getLogger(newName: string): Instance
        return Logger.getLogger(`{name}.{newName}`)
    end

    return table.freeze(logger)
end

--[[
    **Log levels:**
    * 1 -> debug
    * 2 -> info
    * 3 -> warn
    * 4 -> error
    * 5 -> critical
]]
function Logger.setLevel(newLevel: number)
    level = newLevel
end

--[[
    **Log levels:**
    * 1 -> debug
    * 2 -> info
    * 3 -> warn
    * 4 -> error
    * 5 -> critical
]]
function Logger.getLevel(): number
    return level
end

Logger.resolveMessage = resolveMessage

--- Replace log function that logger instance (from Logging.getLogger) uses
---
--- **Log levels:**
--- * 1 -> debug
--- * 2 -> info
--- * 3 -> warn
--- * 4 -> error
--- * 5 -> critical
---
--- @param fn Log function, use `Logging.resolveMessage(formatOrFn, ...)` to resolve `formatOrFn` parameter
function Logger.replaceLogger(fn: (name: string, formatOrFn: string | () -> string, logLevel: number, ...any) -> ())
    log = fn
end

return table.freeze(Logger)