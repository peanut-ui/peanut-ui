--!strict
--!optimize 2
const ComponentContext = require(script.Parent.ComponentContext)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)
const Undefined = require(script.Parent.Undefined)

const logger = Logging.getLogger("PeanutUI.Utils.Ref")

local proxyToRefMap: {[any]: Utils.Ref<any>} = setmetatable({}, { __mode = "k" })
local proxyCache: {[{[any]: any}]: {[any]: any}} = setmetatable({}, { __mode = "k" })
local proxySwap: {[{[any]: any}]: ({[any]: any}, boolean?) -> ()} = setmetatable({}, { __mode = "k" })
local proxyChildWatchers: {[{[any]: any}]: {[any]: () -> ()}} = setmetatable({}, { __mode = "k" })
local rawCache: {[{[any]: any}]: {[any]: any}} = setmetatable({}, { __mode = "k" })

local Ref = {}
Ref.Undefined = Undefined

type Readable<T> = {
    read getValue: () -> T,
}

type Watchable = {
    read watch: (...any) -> ...any,
}

local function createReactiveProxy(rawTarget: {[any]: any}, isShallow: boolean?): any
    if proxyCache[rawTarget] then
        return proxyCache[rawTarget]
    end

    local proxy = {}
    local myRef = Ref.new(proxy)
    proxyToRefMap[proxy] = myRef
    
    local childWatchers: {[any]: () -> ()} = {}
    proxyChildWatchers[proxy] = childWatchers

    local function watchChild(key: any, childRaw: any)
        if type(childRaw) == "table" then
            local childProxy = createReactiveProxy(childRaw)
            local childRef = proxyToRefMap[childProxy]
            
            childWatchers[key] = childRef.watch(function()
                myRef.notifyChanged()
            end)
        end
    end

    local function swap(newTarget: {[any]: any}, suppressEvent: boolean?)
        local oldTarget = rawTarget
        rawTarget = newTarget

        proxyCache[oldTarget] = nil
        proxyCache[newTarget] = proxy
        rawCache[proxy] = newTarget

        for k, unwatch in pairs(childWatchers) do
            unwatch()
        end
        table.clear(childWatchers)

        for k, v in pairs(rawTarget) do
            watchChild(k, v)
        end

        if not suppressEvent then
            myRef.notifyChanged()
        end
    end

    proxySwap[proxy] = swap

    for k, v in pairs(rawTarget) do
        watchChild(k, v)
    end

    local meta = {
        __index = function(_, key)
            local val = rawTarget[key]
            if isShallow ~= true and type(val) == "table" then
                return createReactiveProxy(val)
            end
            return val
        end,

        __newindex = function(_, key, val)
            local cleanVal = rawCache[val] or val
            if rawTarget[key] == cleanVal then return end

            if isShallow ~= true then
                if childWatchers[key] then
                    childWatchers[key]()
                    childWatchers[key] = nil
                end

                watchChild(key, cleanVal)
            end

            rawTarget[key] = cleanVal
            myRef.notifyChanged()
        end,

        __len = function(_) return #rawTarget end,
        __iter = function(_) return next, rawTarget end,
    }

    setmetatable(proxy, meta)
    proxyCache[rawTarget] = proxy
    rawCache[proxy] = rawTarget

    return proxy
end

local function assertType(a: any, b: any)
    if (a ~= nil and b ~= nil) and typeof(a) ~= typeof(b) then
        logger.error(`Type mismatch! {typeof(a)} ~= {typeof(b)}`)
    end
end

function Ref.new<T>(value: T | Utils.Ref<T>): Utils.Ref<T>
    local ref = {}
    ref._typeName = "ref" :: "ref"

    local counter = 0
    local stopWatchingFunc: () -> ()? = nil
    local watchers: {[number]: Utils.RefWatchFn<T>} = {}
    local watchersOnUnwatch: {[number]: () -> ()} = {}
    local currentValue

    local isDestroyed = false

    local cleanups: {() -> ()} = {}

    local scheduled = false
    local function notifyImmediate()
        if isDestroyed then return end

        local watcherClone = table.clone(watchers)
        if next(watchers) == nil then
            return
        end

        for id, watcher in pairs(watcherClone) do
            if not watchers[id] then
                return
            end

            local ok, result = ComponentContext.withNoContext(watcher :: any, currentValue)
            if not ok or result == true then
                watchers[id] = nil
                local onUnwatch = watchersOnUnwatch[id]
                watchersOnUnwatch[id] = nil
                if onUnwatch then
                    onUnwatch()
                end
            end
        end
    end
    
    local function notifyWatchers()
        if isDestroyed then return end
        if scheduled then return end
        scheduled = true

        task.defer(function()
            scheduled = false
            notifyImmediate()
        end)
    end

    local function ensureNotDestroyed()
        if isDestroyed then
            logger.critical("Tried to access Ref after it was destroyed")
        end
    end

    function ref.getValue(): T
        ensureNotDestroyed()
        return currentValue
    end

    function ref.increaseValue(amount: number)
        ensureNotDestroyed()

        if typeof(currentValue) ~= "number" then
            logger.error("Cannot increase non-number")
            error("")
        end

        currentValue += amount
        notifyWatchers()
    end

    function ref.setValue(newValue: T | Utils.Ref<T>, immediate: boolean?)
        ensureNotDestroyed()

        if newValue == currentValue then
            return
        end
        if stopWatchingFunc then
            stopWatchingFunc()
            stopWatchingFunc = nil
        end

        if typeof(newValue) == "table" and newValue._typeName == "ref" then
            local value = (newValue :: Utils.Ref<T>).getValue()
            assertType(currentValue, value)

            currentValue = value
            stopWatchingFunc = (newValue :: Utils.Ref<T>).watch(function(value)
                currentValue = value
                notifyWatchers()
            end)
        elseif proxyToRefMap[newValue] then
            -- No type checking is needed here
            -- Proxies work only on tables anyways (I think)

            -- Also setting proxy as value so "getValue().something = a" will notify
            currentValue = newValue

            local originalRef = proxyToRefMap[newValue]
            stopWatchingFunc = originalRef.watch(function(value)
                notifyWatchers()
            end)
        else
            assertType(currentValue, newValue)
            currentValue = newValue
        end

        if immediate == true then
            notifyImmediate()
        else
            notifyWatchers()
        end
    end

    function ref.watch(fn: Utils.RefWatchFn<T>, onUnwatch: () -> ()?): (() -> (), number)
        ensureNotDestroyed()

        counter += 1
        local id = counter

        watchers[id] = fn
        watchersOnUnwatch[id] = onUnwatch

        return function()
            watchers[id] = nil
            local onUnwatch = watchersOnUnwatch[id]
            watchersOnUnwatch[id] = nil
            if onUnwatch then
                onUnwatch()
            end
        end, id
    end

    function ref.setOnUnwatch(id: number, onUnwatch: () -> ()?)
        if not watchers[id] then
            return
        end

        watchersOnUnwatch[id] = onUnwatch
    end

    function ref.destroy()
        if isDestroyed then return end
        isDestroyed = true

        if stopWatchingFunc then
            stopWatchingFunc()
            stopWatchingFunc = nil
        end

        table.clear(watchers)
        currentValue = nil :: any

        for _, fn in ipairs(cleanups) do
            fn()
        end
        table.clear(cleanups)
    end

    function ref._addCleanup(fn: () -> ())
        table.insert(cleanups, fn)
    end

    ref.notifyChanged = notifyWatchers
    ref.notifyImmediate = notifyImmediate

    if typeof(value) ~= "table" or value._typeName ~= "ref" then
        currentValue = value
    elseif proxyToRefMap[value] then
        -- Copy-paste :T
        currentValue = value

        local originalRef = proxyToRefMap[value]
        stopWatchingFunc = originalRef.watch(function(value)
            notifyWatchers()
        end)
    else
        currentValue = (value :: Utils.Ref<T>).getValue()
        stopWatchingFunc = (value :: Utils.Ref<T>).watch(function(value)
            currentValue = value
            notifyWatchers()
        end)
    end

    table.freeze(ref)

    local bucket = ComponentContext.getCurrentBucket()
    if bucket then
        table.insert(bucket.createdRefs, ref)
    end

    return ref
end

function Ref.transform<T, R>(originalRef: Watchable & Readable<T>, transformFn: (value: T) -> R): Utils.Ref<R>
    local newRef = Ref.new(transformFn(originalRef.getValue()))

    local unwatch = originalRef.watch(function(value)
        newRef.setValue(transformFn(originalRef.getValue()))
    end)

    newRef._addCleanup(unwatch)

    return newRef
end

function Ref.computed<R>(computeFn: () -> R, dependsOn: {Utils.Ref<any>}): Utils.Ref<R>
    local newRef = Ref.new(computeFn())

    local unwatchers: {() -> ()} = {}
    for _, dependency in ipairs(dependsOn) do
        local unwatch = dependency.watch(function()
            newRef.setValue(computeFn())
        end)
        table.insert(unwatchers, unwatch)
    end

    newRef._addCleanup(function()
        for _, unwatch in ipairs(unwatchers) do
            unwatch()
        end
        table.clear(unwatchers)
    end)

    return newRef
end

function Ref.autoComputed<R>(computeFn: (use: <T>(Watchable & Readable<T>) -> T) -> R): Utils.Ref<R>
    local newRef = Ref.new(nil)
    local lastComputeRefs: {[Utils.Ref<any>]: () -> ()} = {}
    local newComputeRefs: {[Utils.Ref<any>]: boolean} = {}

    local function use(ref: Utils.Ref<any>): any
        newComputeRefs[ref] = true
        return ref.getValue()
    end

    local function computeNewValue()
        table.clear(newComputeRefs)
        newRef.setValue(computeFn(use))

        for ref, _ in newComputeRefs do
            if lastComputeRefs[ref] == nil then
                lastComputeRefs[ref] = ref.watch(computeNewValue)
            end
        end

        for ref, unwatch in pairs(lastComputeRefs) do
            if newComputeRefs[ref] == nil then
                unwatch()
                lastComputeRefs[ref] = nil
            end
        end
    end

    newRef._addCleanup(function()
        for _, unwatch in lastComputeRefs do
            unwatch()
        end

        table.clear(lastComputeRefs)
        table.clear(newComputeRefs)
    end)

    computeNewValue()
    return newRef
end

function Ref.toRaw<T>(proxy: T): T
    return (rawCache[proxy] or proxy) :: T
end

function Ref.getRef<T>(proxy: T): Utils.Ref<T>?
    return proxyToRefMap[proxy]
end

function Ref.toRef<T, K>(tbl: T & {[any]: any}, key: keyof<T> & K): Utils.Ref<index<T, K>>
    local originalRef = proxyToRefMap[tbl]
    if not originalRef then
        logger.error("Ref.toRef can be used only on reactive proxy (see Ref.reactive)")
    end

    local value = tbl[key]
    if proxyToRefMap[value] then
        return proxyToRefMap[value]
    end

    local newRef = Ref.new(value)
    local unwatchOriginal = originalRef.watch(function()
        newRef.setValue(tbl[key])
    end)

    local unwatchNew = newRef.watch(function(newVal)
        if tbl[key] == newVal then return end
        tbl[key] = newVal
    end)

    newRef._addCleanup(function()
        unwatchNew()
        unwatchOriginal()
    end)

    return newRef
end

function Ref.swap<T>(proxy: T, newTable: T & {[any]: any})
    local swap = proxySwap[proxy]
    if not swap then
        logger.error("Ref.swap can be used only on reactive proxy (see Ref.reactive)")
    end

    swap(newTable)

    local myRef = proxyToRefMap[proxy]
    if myRef then
        myRef.notifyChanged()
    end
end

local function deepSwap(proxy: any, newTable: {[any]: any}, seen_: {[any]: boolean}?)
    if type(proxy) ~= "table" or type(newTable) ~= "table" then
        return
    end

    local oldTable = rawCache[proxy]
    if not oldTable or oldTable == newTable then
        return
    end

    local seen = seen_ or {}
    if seen[proxy] then return end
    seen[proxy] = true

    local childWatchers = proxyChildWatchers[proxy]

    if childWatchers then
        for key, _ in pairs(childWatchers) do
            local oldVal = oldTable[key]
            local newVal = newTable[key]

            if type(oldVal) == "table" and type(newVal) == "table" then
                local childProxy = proxyCache[oldVal]
                if childProxy then
                    deepSwap(childProxy, newVal, seen)
                end
            end
        end
    end

    local swap = proxySwap[proxy]
    if swap then
        swap(newTable)
    end
end

function Ref.deepSwap<T>(proxy: T, newTable: T & {[any]: any})
    local swap = proxySwap[proxy]
    if not swap then
        logger.error("Ref.deepSwap can be used only on reactive proxy (see Ref.reactive)")
    end

    deepSwap(proxy, newTable)
end

function Ref.reactive<T>(initialTable: T, isShallow: boolean?): T
    return createReactiveProxy(initialTable, isShallow)
end

return Ref