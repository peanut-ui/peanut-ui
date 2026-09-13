--!strict
const Modifier = require(script.Parent.Modifier)
const TypeFuncs = require(script.Parent.TypeFuncs)
const Utils = require(script.Parent.Utils)
const Widget = require(script.Parent.Widget)

export type KeyOf<Table> = TypeFuncs.KeyOf<Table>
export type Resolve<Table, Key> = TypeFuncs.Resolve<Table, Key>
export type Flatten<Table> = TypeFuncs.Flatten<Table>

export type SpaceProps = {
    [string]: any,

    name: string,
    absoluteSize: Vector2,
    absolutePosition: Vector2,
    absoluteRotation: number,
}

export type ScreenSpaceProps = Flatten<SpaceProps & {
    visible: boolean,
    displayOrder: number,
    zIndexBehavior: Enum.ZIndexBehavior,
    clipToDeviceSafeArea: boolean,
    ignoreGuiInset: boolean,
    safeAreaCompatibility: Enum.SafeAreaCompatibility,
    screenInsets: Enum.ScreenInsets
}>

export type SpaceEvents<Object = LayerCollector> = {
    ChildAdded: (child: Widget.BaseInterface) -> ...boolean?,
    ChildRemoved: (child: Widget.BaseInterface) -> ...boolean?,
    PropertyChanged: (key: string, value: any) -> ...boolean?,
    GuiObjectDestroying: (object: Object) -> ...boolean?,
    Destroying: () -> ...boolean?,
    Destroyed: () -> ...boolean?,

    -- GuiObjectCreated doesn't exist on SpaceEvents because it uses custom object creation
    -- While GuiObjectDestroying is part of Widget.destroy, so it still exists
}

type Unsupported = (...never) -> never

export type Interface<Props = SpaceProps, Object = LayerCollector, Events = SpaceEvents> = {
    _typeName: "space",
    _widgetLike: true,

    _widgetName: string,
    _spaceName: string,
    _uniqueId: number,

    -- Keep API widget-like
    setTransition: Unsupported,
    snapProperty: Unsupported,
    setParent: Unsupported,
    getParent: Unsupported,
    createObject: Unsupported,

    destroy: () -> (),
    isDestroyed: () -> boolean,

    setModifier: <K>(
        name: K & KeyOf<Modifier.Modifiers>,
        params: Resolve<Modifier.Modifiers, K> | Utils.Undefined | {Resolve<Modifier.Modifiers, K> | Utils.Undefined}?
    ) -> (),
    getModifier: <K>(name: K & keyof<Modifier.Components>, index: number?) -> any,

    setProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    getProperty: <K>(key: K & KeyOf<Props>) -> Resolve<Props, K>,
    getRef: <K>(key: K & KeyOf<Props>) -> Utils.ProtectedRef<Resolve<Props, K>>,
    observe: <K>(key: K & KeyOf<Props>, callback: (newValue: Resolve<Props, K>) -> boolean?) -> (() -> ()),
    listen: <K>(name: K & KeyOf<Events>, callback: Resolve<Events, K>) -> (() -> ()),

    addChild: (child: Widget.Interface) -> (),
    removeChild: (child: Widget.Interface, andDestroy: boolean?) -> (),
    clearChildren: () -> (),
    children: {Widget.Interface},

    -- LayerCollector object is ALWAYS created in this type
    getGuiObject: () -> Object,
}

export type InternalInterface<Props = SpaceProps, Object = LayerCollector, Events = SpaceEvents> =
    Widget.InternalFunctions<Props, Object, Events> &
    Interface<Props, Object, Events>

export type ScreenSpace = Interface<ScreenSpaceProps, ScreenGui, SpaceEvents<ScreenGui>>

return {}