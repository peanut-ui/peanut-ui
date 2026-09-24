--!strict
--!optimize 2
const Context = require(script.Parent.Context)
const Logging = require(script.Parent.Logging)
const Utils = require(script.Parent.Parent.Types.Utils)
const Scheduler = require(script.Parent.Scheduler)
const Undefined = require(script.Parent.Undefined)

const logger = Logging.getLogger("PeanutUI.Utils.Ref")

type ComputedInternal = {
    invalidate: () -> (),
    watch: (fn: () -> ...boolean?) -> (() -> ()),
}

type Table = {[any]: any}
local proxyToRefMap: {[any]: Utils.Ref<any>} = setmetatable({}, { __mode = "k" })
local proxyCache: {[Table]: Table} = setmetatable({}, { __mode = "k" })

local proxySwap: {[Table]: (Table, boolean?) -> ()} = setmetatable({}, { __mode = "k" })
local proxyGetRef: {[Table]: (string) -> Utils.Ref<any>} = setmetatable({}, { __mode = "k" })

local proxyChildWatchers: {[Table]: {[any]: () -> ()}} = setmetatable({}, { __mode = "k" })
local rawCache: {[Table]: Table} = setmetatable({}, { __mode = "k" })

local computeInternal: {[any]: ComputedInternal} = setmetatable({}, { __mode = "k" })

local protectedRefCache: {[Utils.Ref<any>]: Utils.ProtectedRef<any>} = setmetatable({}, { __mode = "kv" })

local Ref = {}
Ref.Undefined = Undefined

type ComputedDeps = {[Utils.SimpleRef<any>]: boolean}

local function getComputedBucket(): Utils.Bucket<ComputedDeps>?
    local currentBucket = Context.getCurrentBucket()
    if not currentBucket or currentBucket.contextName ~= "ref" then
        return nil
    end

    return currentBucket
end

local function isInContext()
    return getComputedBucket() ~= nil
end

local function track(ref: Utils.Ref<any>)
    local bucket = getComputedBucket()
    if not bucket then
        return
    end

    bucket.customState[ref] = true
end

local function createReactiveProxy(rawTarget: Table, isShallow: boolean?, createdRefs: {Utils.Ref<any>}?): any
    if rawCache[rawTarget] then
        return rawTarget
    end

    if proxyCache[rawTarget] then
        return proxyCache[rawTarget]
    end

    if not createdRefs then
        local bucket = Context.getCurrentBucket()
        createdRefs = bucket and bucket.createdRefs
    end

    local proxy = {}
    local myRef = Ref.new(proxy, createdRefs)
    proxyToRefMap[proxy] = myRef

    local valueRefs: {[any]: Utils.Ref<any>} = {}

    local childWatchers: {[any]: () -> ()} = {}
    proxyChildWatchers[proxy] = childWatchers

    local function watchChild(key: any, childRaw: any)
        if type(childRaw) == "table" then
            local childProxy = createReactiveProxy(childRaw, nil, createdRefs)
            local childRef = proxyToRefMap[childProxy]

            childWatchers[key] = childRef.watch(function()
                myRef.notifyChanged()
            end)
        end
    end

    local function getRef(key: any)
        if valueRefs[key] then
            return valueRefs[key]
        end

        local newRef = Ref.new(rawTarget[key], createdRefs)
        valueRefs[key] = newRef
        return newRef
    end
    proxyGetRef[proxy] = getRef

    local function swap(newTarget: Table, suppressEvent: boolean?)
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

        for key, ref in valueRefs do
            ref.setValue(newTarget[key])
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
                return createReactiveProxy(val, nil, createdRefs)
            end
            if isInContext() then
                track(getRef(key))
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

            local valueRef = valueRefs[key]
            if valueRef then
                valueRef.setValue(cleanVal)
            end
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

--- Make protected Ref for places where value shouldn't be changed externally
--- Also provides watch and unwatch functions for some cool functional
local function makeProtected<T>(
    ref: Utils.Ref<T> | Utils.ProtectedRef<T>,
    onWatch: () -> ()?,
    onUnwatch: () -> ()?,
    getValue: (() -> T)?,
    allowDestroy: boolean?
): Utils.ProtectedRef<T>
    if ref._isProtected == true then
        return ref
    end

    if protectedRefCache[ref] then
        return protectedRefCache[ref]
    end

    local newProtectedRef = {}
    newProtectedRef._typeName = "ref"
    newProtectedRef._isProtected = true

    if not getValue then
        function newProtectedRef.getValue(): any
            return ref.getValue()
        end
    else
        function newProtectedRef.getValue(): any
            return getValue()
        end
    end

    function newProtectedRef.notifyChanged(): any
        return ref.notifyChanged()
    end

    function newProtectedRef.destroy()
        if allowDestroy == true then
            ref.destroy()
        else
            logger.error("Destroying of this ProtectedRef is not allowed")
        end
    end

    function newProtectedRef.watch(fn: Utils.RefWatchFn<any>, onUnwatchFn: () -> ()?, isSync: boolean?): any
        if onUnwatch then
            if onUnwatchFn then
                local originalOnUnwatchFn = onUnwatchFn
                onUnwatchFn = function()
                    originalOnUnwatchFn()
                    if onUnwatch then
                        onUnwatch()
                    end
                end
            else
                onUnwatchFn = onUnwatch
            end
        end

        local unwatch = ref.watch(fn, onUnwatchFn, isSync)
        if onWatch then
            onWatch()
        end

        return unwatch
    end

    setmetatable(newProtectedRef, {
        __index = function(_, key): T?
            if key == "value" or key == "Value" then
                return newProtectedRef.getValue()
            end
            return nil
        end,
    })
    table.freeze(newProtectedRef)

    protectedRefCache[ref] = newProtectedRef :: any
    ref._addCleanup(function()
        protectedRefCache[ref] = nil
    end)

    return newProtectedRef :: any
end

--- Reactive primitive value
---
--- Doesn't automatically watch for changes in tables.
--- For table use either just `reactive(table)` or `ref(reactive(table))`
---
--- All the updates are scheduled for the next `refs` scheduler tick.
--- Before `refs` scheduler stage is fully drained (empty) it will be running watchers.
---
--- @param value Any primitive value or ref, any ref or reactive table is gonna be watched automatically
--- @param registerTo Internal parameter to register ref to scope, leave nil unless really needed
--- @param beforeGetValue Internal parameter for calling function before get (used in computed)
--- @return Reactive value
---
--- ### Examples
--- ```
--- -- Ref.new is the same as PeanutUI.ref()
--- local ref = Ref.new(0)
--- -- Just watcher
--- local unwatch = ref.watch(function(value: number)
---     print("Value changed: " .. value)
--- end)
--- -- Once watcher
--- ref.watch(function(value: number)
---     print("Value changed (once): " .. value)
---     -- Returning true will automatically unwatch
---     return true
--- end)
--- -- This will print `Value changed: 1` (and the once one too)
--- -- And will unwatch watcher that returned true
--- ref.value = 1
--- -- Later you can do unwatch
--- -- But not in the same tick!
--- -- If you unwatch in the same tick, your callback won't be called
--- unwatch()
--- ```
function Ref.new<T>(
    value: T | Utils.SimpleRef<T>,
    registerTo: {Utils.Ref<any>}?,
    beforeGetValue: () -> ()?
): Utils.Ref<T>
    local ref = {}
    ref._typeName = "ref" :: "ref"

    local counter = 0
    local stopWatchingFunc: () -> ()? = nil
    local watchers: {[number]: Utils.RefWatchFn<T>} = {}
    local syncWatchers: {[number]: Utils.RefWatchFn<T>} = {}

    local watchersOnUnwatch: {[number]: () -> ()} = {}
    local currentValue

    local isDestroyed = false

    local cleanups: {() -> ()} = {}

    local scheduled = false
    local function notifyImmediate(watchers: {[number]: Utils.RefWatchFn<T>})
        if isDestroyed then return end
        if next(watchers) == nil then return end

        if beforeGetValue then beforeGetValue() end

        local watcherClone = table.clone(watchers)
        for id, watcher in pairs(watcherClone) do
            if not watchers[id] then
                return
            end

            local ok, result = Context.withNoContext(watcher :: any, currentValue)
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
        if next(syncWatchers) ~= nil then
            notifyImmediate(syncWatchers)
        end

        if next(watchers) == nil then return end
        if scheduled then return end
        scheduled = true

        Scheduler.schedule("watchers", function()
            scheduled = false
            notifyImmediate(watchers)
        end)
    end

    local function ensureNotDestroyed()
        if isDestroyed then
            logger.critical("Tried to access Ref after it was destroyed")
        end
    end

    function ref.getValue(): T
        ensureNotDestroyed()
        if beforeGetValue then beforeGetValue() end
        track(proxyToRefMap[currentValue] or ref :: any)
        return currentValue :: T
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

    function ref.setValue(newValue: T | Utils.SimpleRef<T>)
        ensureNotDestroyed()

        if newValue == currentValue then
            return
        end
        if stopWatchingFunc then
            stopWatchingFunc()
            stopWatchingFunc = nil
        end

        if newValue ~= nil and proxyToRefMap[newValue] then
            -- No type checking is needed here
            -- Proxies work only on tables anyways (I think)

            -- Also setting proxy as value so "getValue().something = a" will notify
            currentValue = newValue

            local originalRef = proxyToRefMap[newValue]
            stopWatchingFunc = originalRef.watch(function(value)
                notifyWatchers()
            end, nil, true)
        elseif typeof(newValue) == "table" and newValue._typeName == "ref" then
            local value = (newValue :: Utils.Gettable<T>).getValue()
            assertType(currentValue, value)

            currentValue = value
            stopWatchingFunc = (newValue :: Utils.Watchable<T>).watch(function(value)
                currentValue = value
                notifyWatchers()
            end, nil, true)
        else
            assertType(currentValue, newValue)
            currentValue = newValue
        end

        notifyWatchers()
    end

    function ref.watch(fn: Utils.RefWatchFn<T>, onUnwatch: () -> ()?, isSync: boolean?): (() -> (), number)
        ensureNotDestroyed()

        counter += 1
        local id = counter

        local watchersToUse = if isSync == true then syncWatchers else watchers

        watchersToUse[id] = fn
        watchersOnUnwatch[id] = onUnwatch

        return function()
            watchersToUse[id] = nil
            local onUnwatch = watchersOnUnwatch[id]
            watchersOnUnwatch[id] = nil
            if onUnwatch then
                onUnwatch()
            end
        end, id
    end

    function ref.setOnUnwatch(id: number, onUnwatch: () -> ()?)
        if not watchers[id] and not syncWatchers[id] then
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
        table.clear(syncWatchers)
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

    ref.setValue(value, true)

    setmetatable(ref, {
        __index = function(_, key): T?
            if key == "value" or key == "Value" then
                return ref.getValue()
            end
            return nil
        end,

        __newindex = function(_, key, val)
            if key == "value" or key == "Value" then
                ref.setValue(val)
            end
        end
    })
    table.freeze(ref)

    if not registerTo then
        local bucket = Context.getCurrentBucket()
        registerTo = bucket and bucket.createdRefs
    end

    if registerTo then
        table.insert(registerTo, ref :: any)
    end

    return ref :: any
end

--- Transformed Ref
---
--- Useful for situations when you need simple transformation of Ref.
---
--- @param originalRef Ref you want to transform
--- @param transformFn Function that will make new value out of original Ref's value
--- @return New Ref that will contain result from `transformFn`
---
--- ### Example
--- ```
--- -- Ref.new is the same as PeanutUI.ref()
--- local clickCount = Ref.new(0)
--- local clickCountString = Ref.transform(clickCount, function(value: number)
---     return `Click count: {value}`
--- end)
--- -- Somewhere in the code:
--- clickCount.value += 1
--- -- Now `clickCountString` is "Click count: 1"
--- ```
function Ref.transform<T, R>(originalRef: Utils.SimpleRef<T>, transformFn: (value: T) -> R): Utils.Ref<R>
    local newRef = Ref.new(transformFn(originalRef.getValue()))

    local unwatch = originalRef.watch(function(value)
        newRef.setValue(transformFn(value))
    end, nil, true)

    newRef._addCleanup(unwatch)

    return newRef
end

--- Check if object is Ref
--- @param obj Any object
--- @return True if object is a Ref
function Ref.isRef(obj: any): boolean
    if typeof(obj) ~= "table" then
        return false
    end

    if obj._typeName == "ref" then
        return true
    end

    return false
end

--- Computed Ref
---
--- Creates a lazily-evaluated reactive value based on other refs. Automatically tracks dependencies
--- accessed during execution and recomputes only when necessary.
---
--- @param computeFn Function that computes and returns the value based on other refs
--- @return ProtectedRef containing the computed value
---
--- ### Example
--- ```
--- local a = Ref.new(2)
--- local b = Ref.new(3)
--- local sum = Ref.computed(function()
---     return a.value + b.value
--- end)
--- print(sum.value) -- 5
--- a.value = 5
--- print(sum.value) -- 8
--- ```
function Ref.computed<R>(computeFn: () -> R): Utils.ProtectedRef<R>
    local isDirty = true
    local computeNewValue: () -> ()

    local newRef = Ref.new(nil, nil, function()
        if isDirty then computeNewValue() end
    end)

    local counter = 0
    local watchers: {[number]: () -> ...boolean?} = {}

    local lastComputeRefs: {[Utils.SimpleRef<any>]: () -> ()} = {}

    local watchingCounter = 0

    local protectedRef: Utils.ProtectedRef<R>
    local invalidate: () -> ()

    local function watch(fn: () -> ...boolean?): () -> ()
        counter += 1
        local id = counter

        watchers[id] = fn

        return function()
            watchers[id] = nil
        end
    end

    local function notify()
        if next(watchers) == nil then return end

        local watcherClone = table.clone(watchers)
        for id, watcher in pairs(watcherClone) do
            if not watchers[id] then
                return
            end

            local ok, result = Context.withNoContext(watcher :: any)
            if not ok or result == true then
                watchers[id] = nil
            end
        end
    end

    local isComputing = false
    function computeNewValue()
        if isComputing then
            logger.error("Circular dependency detected in computed property!")
            error("")
        end
        if not isDirty then return end

        isComputing = true
        local newComputeRefs = {} :: ComputedDeps

        newComputeRefs[protectedRef] = nil
        newComputeRefs[newRef] = nil

        local bucket = Context.createBucket("ref", newComputeRefs)

        local ok, result = Context.withContextBucket(bucket, function()
            return computeFn()
        end)
        if not ok then
            logger.error(`Couldn't calculate result for computed:\n{result}`)
            error("")
        end

        isDirty = false
        newRef.setValue(result)

        for ref, _ in newComputeRefs do
            if lastComputeRefs[ref] == nil then
                local internal = computeInternal[ref :: any]
                if internal then
                    lastComputeRefs[ref] = internal.watch(invalidate)
                else
                    lastComputeRefs[ref] = ref.watch(invalidate, nil, true)
                end
            end
        end

        for ref, unwatch in pairs(lastComputeRefs) do
            if newComputeRefs[ref] == nil then
                unwatch()
                lastComputeRefs[ref] = nil
            end
        end
        isComputing = false
    end

    local scheduled = false
    invalidate = function()
        if isDirty then return end
        isDirty = true

        if watchingCounter > 0 and not scheduled then
            scheduled = true
            Scheduler.schedule("watchers", function()
                scheduled = false
                if isDirty then
                    computeNewValue()
                end
            end)
        end

        notify()
    end

    newRef._addCleanup(function()
        for _, unwatch in lastComputeRefs do
            unwatch()
        end

        table.clear(lastComputeRefs)
    end)

    protectedRef = makeProtected(
        newRef :: Utils.Ref<R>,
        function()
            watchingCounter += 1
            if isDirty then
                computeNewValue()
            end
        end,
        function()
            watchingCounter -= 1
            if watchingCounter <= 0 then
                watchingCounter = 0
            end
        end,
        nil,
        true
    )

    local internal = {
        invalidate = invalidate,
        watch = watch
    }
    computeInternal[protectedRef] = internal
    computeInternal[newRef] = internal

    return protectedRef
end

--- Get Raw Table
---
--- Unwraps a reactive proxy and returns the underlying raw, unproxied target table.
---
--- @param proxy Reactive proxy table
--- @return The raw underlying table
---
--- ### Example
--- ```
--- local proxy = Ref.reactive({ a = 1 })
--- local raw = Ref.toRaw(proxy)
--- print(raw == proxy) -- false
--- ```
function Ref.toRaw<T>(proxy: T): T
    return (rawCache[proxy] or proxy) :: T
end

--- Get Proxy Ref
---
--- Retrieves the internal `Ref` object associated with a reactive proxy table.
---
--- @param proxy Reactive proxy table
--- @return The internal Ref object, or nil if not a proxy
---
--- ### Example
--- ```
--- local proxy = Ref.reactive({ a = 1 })
--- local refObj = Ref.getRef(proxy)
--- ```
function Ref.getRef<T>(proxy: T): Utils.Ref<T>?
    return proxyToRefMap[proxy]
end

--- To Ref
---
--- Gets or creates a reactive `Ref` wrapping a specific field of a reactive proxy table.
---
--- @param tbl Reactive proxy table
--- @param key Key of the property inside the table
--- @return Ref wrapping the specified property
---
--- ### Example
--- ```
--- local proxy = Ref.reactive({ count = 0 })
--- local countRef = Ref.toRef(proxy, "count")
--- countRef.value += 1
--- ```
function Ref.toRef<T, K>(tbl: T & Table, key: keyof<T> & K): Utils.Ref<index<T, K>>
    local getRef = proxyGetRef[tbl]
    if not getRef then
        logger.error("Ref.toRef can be used only on reactive proxy (see Ref.reactive)")
    end

    return getRef(key)
end

--- Swap Table
---
--- Replaces the underlying raw target of a reactive proxy with a new table, updating all existing fields.
---
--- @param proxy Reactive proxy table
--- @param newTable New table data to swap in
---
--- ### Example
--- ```
--- local proxy = Ref.reactive({ a = 1 })
--- Ref.swap(proxy, { a = 2 })
--- ```
function Ref.swap<T>(proxy: T, newTable: T & Table)
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

local function deepSwap(proxy: any, newTable: Table, seen_: {[any]: boolean}?)
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

--- Deep Swap Table
---
--- Recursively replaces underlying tables across nested reactive proxies and their child proxies.
---
--- @param proxy Reactive proxy table
--- @param newTable New nested table data to swap in
---
--- ### Example
--- ```
--- local proxy = Ref.reactive({ nested = { a = 1 } })
--- Ref.deepSwap(proxy, { nested = { a = 5 } })
--- ```
function Ref.deepSwap<T>(proxy: T, newTable: T & Table)
    local swap = proxySwap[proxy]
    if not swap then
        logger.error("Ref.deepSwap can be used only on reactive proxy (see Ref.reactive)")
    end

    deepSwap(proxy, newTable)
end

--- Reactive Proxy
---
--- Wraps a table into a deep reactive proxy that automatically tracks property accesses and mutations.
---
--- @param initialTable Initial raw table data
--- @param isShallow Optional flag to make proxy shallow (non-nested reactivity)
--- @return Reactive proxy table
---
--- ### Example
--- ```
--- local state = Ref.reactive({ health = 100 })
--- state.health -= 10
--- ```
function Ref.reactive<T>(initialTable: T, isShallow: boolean?): T
    return createReactiveProxy(initialTable, isShallow)
end

Ref.makeProtected = makeProtected

return table.freeze(Ref)