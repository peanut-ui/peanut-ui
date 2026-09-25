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

export type WidgetEvents = {
    ChildAdded: (child: BaseInterface) -> ...boolean?,
    ChildRemoved: (child: BaseInterface) -> ...boolean?,
    ParentChanged: (newParent: BaseInterface?) -> ...boolean?,
    PropertyChanged: (key: string, value: any) -> ...boolean?,
    ObjectCreated: (object: GuiObject) -> ...boolean?,
    ObjectDestroying: (object: GuiObject) -> ...boolean?,
    Destroying: () -> ...boolean?,
    Destroyed: () -> ...boolean?,

    BeforeObjectCreated: () -> ...boolean?,
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
} & WidgetEvents

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

    sizeConstraint: Enum.SizeConstraint,
    automaticSize: Enum.AutomaticSize,

    selectable: boolean,
    selectionOrder: number,

    selectionImageObject: Utils.SimpleRef<GuiObject?>?,
    nextSelectionDown: Utils.SimpleRef<GuiObject?>?,
    nextSelectionUp: Utils.SimpleRef<GuiObject?>?,
    nextSelectionRight: Utils.SimpleRef<GuiObject?>?,
    nextSelectionLeft: Utils.SimpleRef<GuiObject?>?,

    interactable: boolean,
    active: boolean,

    backgroundColor: Color3,
    backgroundTransparency: number,

    absoluteSize: Vector2,
    absolutePosition: Vector2,
    absoluteRotation: number,

    inputSink: Enum.InputSink,

    borderColor: Color3,
    borderMode: Enum.BorderMode,
    borderSizePx: number,

    name: string
}

export type ScaleCallback = (number, getOriginal: boolean?) -> number
export type ScaleFn = ScaleCallback | {
    fn: ScaleCallback,
    stop: () -> ()
}

export type SpaceLike<Object = any> = WidgetLike & {
    _isSpaceLike: true,
    signals: Utils.Signals,

    scaleObject: <T>(value: T, getOriginal: boolean?) -> T,
    changeScaleFn: (ScaleFn) -> (),

    getObject: () -> Object,
    getObjectRef: () -> Utils.Ref<Object>,
}

-- feature: properties
export type PropertiesFeature = {
    setProperty: (key: string, value: any | Utils.Ref<any>) -> (),
    getProperty: (key: string) -> any,
    observe: (key: string, callback: (newValue: any) -> boolean?) -> (() -> ()),

    _linkProperty: (
        name: string, object: string,
        transformFn: ((value: any) -> any)?,
        syncWithObject: (boolean | (any) -> any)?,
        readonly: boolean?,
        redrawOnHooks: {string}?
    ) -> (),
    _propertiesRefs: {[string]: Utils.Ref<any>},

    getRef: (key: string) -> Utils.ProtectedRef<any>,
}

-- feature: transitions
export type TransitionsFeature = {
    setTransition: (key: string, transition: Animations.Transition?) -> (),
    snapProperty: (key: string, value: any | Utils.Ref<any>) -> (),
}

-- feature: events
export type EventsFeature = {
    listen: (name: string, callback: any) -> (() -> ()),
    _linkEvent: (name: any, event: string?) -> (),
}

-- feature: parenting
export type ParentingFeature = {
    setParent: (parent: WidgetLike) -> (),
    getParent: () -> BaseInterface,

    _setParent: (parent: BaseInterface?) -> (),
    _setSpace: (space: SpaceLike?) -> (),

    getSpace: () -> SpaceLike?
}

-- feature: children
export type ChildrenFeature = {
    addChild: (child: WidgetLike) -> (),
    removeChild: (child: WidgetLike, andDestroy: boolean?) -> (),
    clearChildren: () -> (),
    children: {BaseInterface},
}

-- feature: modifiers
export type ModifiersFeature = {
    setModifier: <K>(name: K & keyof<Modifier.Modifiers>, params: any?) -> (),
    getModifier: <K>(name: K & keyof<Modifier.Components>, index: number?) -> any,
}

-- feature: animations
export type AnimationsFeature = {
    setAnimation: (name: string, animation: (Animations.Animation | Animations.UnresolvedAnimation)?) -> (),
    getAnimation: (name: string) -> Animations.AnimationControl?
}

export type Features = {
    events: EventsFeature,
    properties: PropertiesFeature,

    transitions: TransitionsFeature,
    parenting: ParentingFeature,
    children: ChildrenFeature,
    modifiers: ModifiersFeature,
    animations: AnimationsFeature
}

export type WidgetLike = {
    _typeName: string,
    _widgetLike: true,
    _widgetName: string,
    _uniqueId: number,
    _features: {[keyof<Features>]: boolean},

    destroy: () -> (),
    isDestroyed: () -> boolean,

    isImplemented: (field: string, isFeature: boolean?) -> boolean
}

-- Similar to <template> in Vue.js
export type Box = {
    _boxName: string,

    _createObject: () -> GuiObject?,
    _redraw: () -> (),
    _addCleanup: (RBXScriptConnection | () -> ()) -> (),

    getObjectRef: () -> Utils.ProtectedRef<Instance?>,
    getObject: () -> Instance?,
} & WidgetLike
    & ParentingFeature
    & ChildrenFeature
    & EventsFeature

export type BaseInterface = {
    _setCreateObject: (() -> Instance?) -> (),

    _createObject: () -> Instance?,
    _redraw: () -> (),
    _addCleanup: (RBXScriptConnection | () -> ()) -> (),
    _setObject: (object: Instance) -> (),

    getObjectRef: () -> Utils.ProtectedRef<Instance?>,
    getObject: () -> Instance?,
} & WidgetLike
    & ChildrenFeature
    & ParentingFeature
    & EventsFeature
    & TransitionsFeature
    & PropertiesFeature
    & ModifiersFeature
    & AnimationsFeature

--- Typed interface!
export type Interface<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> = WidgetLike & {
    setModifier: <K>(
        name: K & KeyOf<Modifier.Modifiers>,
        params: Resolve<Modifier.Modifiers, K> | Utils.Undefined | {Resolve<Modifier.Modifiers, K> | Utils.Undefined}?
    ) -> (),
    getModifier: <K>(name: K & Modifier.ComponentNames, index: number?) -> Resolve<Modifier.Components, K>,

    setTransition: <K>(key: K & KeyOf<Props>, transition: Animations.Transition?) -> (),

    setProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.SimpleRef<Resolve<Props, K>>) -> (),
    snapProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.SimpleRef<Resolve<Props, K>>) -> (),
    getProperty: <K>(key: K & KeyOf<Props>) -> Resolve<Props, K>,
    getRef: <K>(key: K & KeyOf<Props>) -> Utils.ProtectedRef<Resolve<Props, K>>,
    observe: <K>(key: K & KeyOf<Props>, callback: (newValue: Resolve<Props, K>) -> ...boolean?) -> (() -> ()),
    listen: <K>(name: K & KeyOf<Events>, callback: Resolve<Events, K>) -> (() -> ()),

    setParent: (parent: WidgetLike?) -> (),
    getParent: () -> Interface?,
    addChild: (child: WidgetLike) -> (),
    removeChild: (child: WidgetLike, andDestroy: boolean?) -> (),
    clearChildren: () -> (),
    children: {Interface},

    setAnimation: (name: string, animation: (Animations.Animation | Animations.UnresolvedAnimation)?) -> (),
    getAnimation: (name: string) -> Animations.AnimationControl,

    getSpace: () -> SpaceLike?,

    getObject: () -> (Object?),
    getObjectRef: () -> Utils.ProtectedRef<Object?>,
}

export type InternalFunctions<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> = {
    _setCreateObject: (() -> Object?) -> (),
    _linkProperty: <K>(
        name: K & KeyOf<Props>, object: string,
        transformFn: ((value: Resolve<Props, K>) -> any)?,
        syncWithObject: (boolean | (any) -> any)?,
        readonly: boolean?,
        redrawOnHooks: {string}?
    ) -> (),
    _linkEvent: <K>(name: K & KeyOf<Events>, event: string?) -> (),
    _setParent: (parent: Interface?) -> (),
    _createObject: () -> (),
    _redraw: () -> (),
    _addCleanup: (RBXScriptConnection | () -> ()) -> (),
    _propertiesRefs: {[string]: Utils.Ref<any>},
    _setSpace: (space: SpaceLike?) -> (),
    _setObject: (object: Object) -> ()
}

export type InternalInterface<Props = DefaultProperties, Object = GuiObject, Events = DefaultEvents> =
    Interface<Props, Object, Events> &
    InternalFunctions<Props, Object, Events>

export type Args<Props = DefaultProperties, Widget = Interface, Events = DefaultEvents> = {
    children: {any}?,
    properties: Partial<UnionProperties<Props, Utils.SimpleRef<any>>>?,
    events: Partial<Events>?,
    transitions: {[keyof<Props>]: Animations.Transition}?,
    modifiers: Modifier.Modifiers?,
    animations: {[string]: Animations.Animation}?,
    onSetup: (widget: Widget) -> ()?,
    defaultSetupOverride: (Utils.Undefined | (widget: Widget, defaultFn: (widget: Widget) -> ()) -> ())?,
    widgetName: string?
}

return {}
