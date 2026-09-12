--!strict
const Animations = require(script.Parent.Animations)
const Modifier = require(script.Parent.Modifier)
const TypeFuncs = require(script.Parent.TypeFuncs)
const Utils = require(script.Parent.Utils)

export type KeyOf<Table> = TypeFuncs.KeyOf<Table>
export type Resolve<Table, Key> = TypeFuncs.Resolve<Table, Key>
export type Partial<Table> = TypeFuncs.Partial<Table>
export type UnionProperties<Table, UnionWith> = TypeFuncs.UnionProperties<Table, UnionWith>

export type ReadOnlyArray<T> = {
	read [number]: T,
}

export type DefaultEvents = {
    [string]: (...any) -> ...boolean?,

    -- GuiObject
    InputBegan: (inputObject: InputObject) -> ...boolean?,
    InputChanged: (inputObject: InputObject) -> ...boolean?,
    InputEnded: (inputObject: InputObject) -> ...boolean?,

    MouseEnter: (x: number, y: number) -> ...boolean?,
    MouseMoved: (x: number, y: number) -> ...boolean?,
    MouseLeave: (x: number, y: number) -> ...boolean?,

    MouseWheelBackward: (x: number, y: number) -> ...boolean?,
    MouseWheelForward: (x: number, y: number) -> ...boolean?,

    SelectionChanged: (amISelected: boolean, previousSelection: GuiObject, newSelection: GuiObject) -> ...boolean?,
    SelectionGained: () -> ...boolean?,
    SelectionLost: () -> ...boolean?,

    TouchLongPress: (touchPositions: {Vector2}, state: Enum.UserInputState) -> ...boolean?,
    TouchPan: (touchPositions: {Vector2}, totalTranslation: Vector2, velocity: Vector2, state: Enum.UserInputState) -> ...boolean?,
    TouchPinch: (touchPositions: {Vector2}, scale: number, velocity: number, state: Enum.UserInputState) -> ...boolean?,
    TouchTap: (touchPositions: {Vector2}) -> ...boolean?,

    -- Widget
    ChildAdded: (child: BaseInterface) -> ...boolean?,
    ChildRemoved: (child: BaseInterface) -> ...boolean?,
    ParentChanged: (newParent: BaseInterface?) -> ...boolean?,
    PropertyChanged: (key: string, value: any) -> ...boolean?,
    GuiObjectCreated: (object: GuiObject) -> ...boolean?,
    GuiObjectDestroying: (object: GuiObject) -> ...boolean?,
    Destroying: () -> ...boolean?,
    Destroyed: () -> ...boolean?,
}

export type DefaultProperties = {
    [string]: any,

    visible: boolean,
    layoutOrder: number,
    autoLayoutOrder: number,
    zIndex: number,
    clipsDescendants: boolean,

    size: Utils.Size,
    position: Utils.Position,
    anchorPoint: Vector2,
    rotation: number,

    backgroundColor: Color3,
    backgroundTransparency: number,

    absoluteSize: Vector2,
    absolutePosition: Vector2,
    absoluteRotation: number,

    name: string
}

export type WidgetLike = {
    _typeName: "widget"
} | {
    _widgetLike: true
}

export type BaseInterface = {
    _typeName: "widget",
    _widgetName: string,
    _uniqueId: number,

    createObject: (() -> GuiObject)?,
    destroy: () -> (),
    isDestroyed: () -> boolean,

    setModifier: <K>(name: K & keyof<Modifier.Modifiers>, params: any?) -> (),
    getModifier: <K>(name: K & keyof<Modifier.Components>, index: number?) -> any,

    setProperty: (key: string, value: any | Utils.Ref<any>) -> (),
    setTransition: (key: string, transition: Animations.Transition?) -> (),
    snapProperty: (key: string, value: any | Utils.Ref<any>) -> (),
    getProperty: (key: string) -> any,
    observe: (key: string, callback: (newValue: any) -> boolean?) -> (() -> ()),
    listen: (name: string, callback: any) -> (() -> ()),

    setParent: (parent: WidgetLike) -> (),
    getParent: () -> BaseInterface,
    addChild: (child: WidgetLike) -> (),
    removeChild: (child: WidgetLike, andDestroy: boolean?) -> (),
    clearChildren: () -> (),
    children: {BaseInterface},

    _linkProperty: (
        name: string, object: string,
        transformFn: ((value: any) -> any)?,
        syncWithObject: (boolean | (any) -> any)?,
        readonly: boolean?
    ) -> (),
    _linkEvent: (name: any, event: string?) -> (),
    _setParent: (parent: BaseInterface?) -> (),
    _createObject: () -> Object?,
    _redraw: () -> (),
    _addCleanup: (RBXScriptConnection | () -> ()) -> (),
    _propertiesRefs: {[string]: Utils.Ref<any>},

    getGuiObject: () -> Object?,
}

export type Interface<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> = {
    _typeName: "widget",
    _widgetName: string,
    _uniqueId: number,

    createObject: (() -> Object)?,
    destroy: () -> (),
    isDestroyed: () -> boolean,

    setModifier: <K>(
        name: K & KeyOf<Modifier.Modifiers>,
        params: Resolve<Modifier.Modifiers, K> | Utils.Undefined | {Resolve<Modifier.Modifiers, K> | Utils.Undefined}?
    ) -> (),
    getModifier: <K>(name: K & keyof<Modifier.Components>, index: number?) -> any,

    setTransition: <K>(key: K & KeyOf<Props>, transition: Animations.Transition?) -> (),

    setProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    snapProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    getProperty: <K>(key: K & KeyOf<Props>) -> Resolve<Props, K>,
    observe: <K>(key: K & KeyOf<Props>, callback: (newValue: Resolve<Props, K>) -> ...boolean?) -> (() -> ()),
    listen: <K>(name: K & KeyOf<Events>, callback: Resolve<Events, K>) -> (() -> ()),

    setParent: (parent: WidgetLike?) -> (),
    getParent: () -> Interface?,
    addChild: (child: WidgetLike) -> (),
    removeChild: (child: WidgetLike, andDestroy: boolean?) -> (),
    clearChildren: () -> (),
    children: {Interface},

    getGuiObject: () -> (Object?),
}

export type InternalFunctions<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> = {
    _linkProperty: <K>(
        name: K & KeyOf<Props>, object: string,
        transformFn: ((value: Resolve<Props, K>) -> any)?,
        syncWithObject: (boolean | (any) -> any)?,
        readonly: boolean?
    ) -> (),
    _linkEvent: <K>(name: K & KeyOf<Events>, event: string?) -> (),
    _setParent: (parent: Interface?) -> (),
    _createObject: () -> Object?,
    _redraw: () -> (),
    _addCleanup: (RBXScriptConnection | () -> ()) -> (),
    _propertiesRefs: {[string]: Utils.Ref<any>},
    _setObject: (object: Object) -> ()
}

export type InternalInterface<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> =
    Interface<Props, Object, Events> &
    InternalFunctions<Props, Object, Events>

export type Args<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> = {
    children: {any}?,
    properties: Partial<UnionProperties<Props, Utils.Ref<any>>>?,
    events: Partial<UnionProperties<Events, Utils.Ref<any>>>?,
    transitions: {[keyof<Props>]: Animations.Transition}?,
    modifiers: Modifier.Modifiers?,
    onSetup: (widget: Interface<Props, Object, Events>) -> ()?,
    defaultSetupOverride: (widget: Interface<Props, Object, Events>, defaultFn: (widget: Interface<Props, Object, Events>) -> ()) -> ()?,
    widgetName: string?
}

return {}
