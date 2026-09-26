--!strict

export type RefWatchFn<T> = (value: T) -> ...boolean?
export type Ref<T> = {
    read _typeName: "ref",
    read _isProtected: nil,
    read getValue: () -> T,
    read setValue: (value: T | Ref<T> | ProtectedRef<T>) -> (),
    read increaseValue: (number) -> (),
    read notifyChanged: () -> (),
    read watch: (fn: RefWatchFn<T>, onUnwatch: () -> ()?, isSync: boolean?) -> (() -> (), number),
    read setOnUnwatch: (id: number, onUnwatch: () -> ()?) -> (),
    read destroy: () -> (),

    read value: T,
    write value: T | Ref<T> | ProtectedRef<T>,

    read _addCleanup: (() -> ()) -> ()
}

export type Gettable<T> = {
    read getValue: () -> T,
}

export type Watchable<T> = {
    read watch: (fn: RefWatchFn<T>, onUnwatch: () -> ()?, isSync: boolean?) -> (() -> (), number),
}

export type SimpleRef<T> = {
    read _typeName: "ref",
    read getValue: () -> T,
    read watch: (fn: RefWatchFn<T>, onUnwatch: () -> ()?, isSync: boolean?) -> (() -> (), number),
}

export type ProtectedRef<T> = {
    read _typeName: "ref",
    read _isProtected: true,
    read getValue: () -> T,
    read notifyChanged: () -> (),
    read watch: (fn: RefWatchFn<T>, onUnwatch: () -> ()?, isSync: boolean?) -> (() -> (), number),
    read value: T,
    read destroy: () -> (),
}

export type Undefined = "__peanutui__undefined__"
export type Optional<T> = T | Undefined

export type SignalsCallback = () -> ...boolean?
export type Signals = {
    read _typeName: "signals",
    read listen: (signal: string, callback: SignalsCallback) -> (() -> ()),
    read fire: (signal: string) -> (),
    read destroy: () -> ()
}

export type HooksCallback = (...any) -> ()
export type Hooks = {
    read _typeName: "hooks",
    read add: (key: string, callback: HooksCallback) -> (),
    read fire: (key: string, ...any) -> (),
    read clear: () -> ()
}

export type EventsCallback = (...any) -> ...boolean?
export type EventsListeners = {[string]: {[EventsCallback]: boolean}}
export type Events = {
    read _typeName: "events",
    read listeners: EventsListeners,
    read listen: (event: string, callback: EventsCallback) -> (() -> ()),
    read fire: (event: string, ...any) -> (),
    read destroy: () -> ()
}

export type Size = {
    _typeName: "size",
    width: number,
    height: number,
    widthScale: number,
    heightScale: number,
}

export type Position = {
    _typeName: "position",
    x: number,
    y: number,
    xScale: number,
    yScale: number
}

export type Unit = {
    _typeName: "unit",
    px: number,
    scale: number
}

export type Bucket<State = any?> = {
    cleanups: {[number]: () -> ()},
    customState: State,
    contextName: string,

    addCleanup: (() -> ()) -> number,
    removeCleanup: (number) -> (),
    stop: () -> ()
}

return {}