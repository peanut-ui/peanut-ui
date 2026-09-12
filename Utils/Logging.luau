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

local function resolveMessage(formatOrFn: string | () -> string, ...: any): string
    if typeof(formatOrFn) == "function" then
        return formatOrFn()
    elseif select("#", ...) > 0 then
        return string.format(formatOrFn, ...)
    else
        return formatOrFn
    end
end

local function log(name: string, formatOrFn: string | () -> string, logLevel: number, ...: any)
    if logLevel < level then
        return
    end

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

function Logger.getLogger(name: string): Instance
    local logger = {}
    logger.name = name

    function logger.debug(string: string | () -> string, ...): ()
        log(name, string, 1, ...)
    end

    function logger.info(string: string | () -> string, ...): ()
        log(name, string, 2, ...)
    end

    function logger.warn(string: string | () -> string, ...): ()
        log(name, string, 3, ...)
    end

    function logger.error(string: string | () -> string, ...)
        log(name, string, 4, ...)
        error(string)  -- In case log doesn't stop execution
    end

    function logger.critical(string: string | () -> string, ...)
        log(name, string, 5, ...)
        error(string)  -- Same as in logger.error
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

--- Resolves `formatOrFn` object
Logger.resolveMessage = resolveMessage

--[[
    **Log levels:**
    * 1 -> debug
    * 2 -> info
    * 3 -> warn
    * 4 -> error
    * 5 -> critical
]]
function Logger.replaceLogger(fn: (name: string, formatOrFn: string | () -> string, logLevel: number, ...any) -> ())
    Logger.setLevel = function()
        log("Logging", "Custom logger was set, can't change level", 3)
    end

    log = fn
end

return Logger