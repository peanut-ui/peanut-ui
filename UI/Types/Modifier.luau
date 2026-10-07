--!strict
--!optimize 2
const Animations = require(script.Parent.Animations)
const TypeFuncs = require(script.Parent.TypeFuncs)
const Utils = require(script.Parent.Utils)

export type KeyOf<Table> = TypeFuncs.KeyOf<Table>
export type Resolve<Table, Key> = TypeFuncs.Resolve<Table, Key>
export type Partial<Table> = TypeFuncs.Partial<Table>

-- Styling and shape
export type Flex = {
    mode: "Fill" | "Grow" | "None" | "Shrink" | "Custom",
    lineAlignment: "Automatic" | "Center" | "End" | "Start" | "Stretch",
    growRatio: number,
    shrinkRatio: number
}

export type CornerRadius = {
    topLeft: Utils.Unit?,
    topRight: Utils.Unit?,
    bottomLeft: Utils.Unit?,
    bottomRight: Utils.Unit?,
    all: Utils.Unit
}

export type Padding = {
    left: Utils.Unit?,
    right: Utils.Unit?,
    top: Utils.Unit?,
    bottom: Utils.Unit?,
    all: Utils.Unit,
}

export type Stroke = {
    enabled: boolean,
    zIndex: number,
    color: Color3,
    transparency: number,
    thickness: number,
    borderOffset: Utils.Unit,
    strokeMode: "Border" | "Contextual",
    borderPosition: "Center" | "Inner" | "Outer",
    lineJoinMode: "Bevel" | "Miter" | "Round"
}

export type Gradient = {
    enabled: boolean,
    color: ColorSequence,
    offset: Vector2,
    scale: number,
    rotation: number,
    transparency: NumberSequence,
    tileMode: "Clamp" | "Mirror" | "Repeat",
    type: "Conical" | "Linear" | "Radial"
}

export type Shadow = {
    enabled: boolean,
    blurRadius: Utils.Unit,
    color: Color3,
    offset: Utils.Position,
    spread: Utils.Size,
    transparency: number,
    zIndex: number
}

-- Layouts
export type List = {
    gap: Utils.Unit,
    horizontal: boolean,
    sortByName: boolean,
    wraps: boolean,
    absoluteContentSize: Vector2,
    horizontalAlign: "Left" | "Center" | "Right",
    verticalAlign: "Top" | "Center" | "Bottom",
    horizontalFlex: "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly",
    lineAlignment: "Automatic" | "Center" | "End" | "Start" | "Stretch",
}

export type Grid = {
    gap: Utils.Size,
    cellSize: Utils.Size,
    horizontal: boolean,
    sortByName: boolean,
    fillDirectionMaxCells: number,
    absoluteContentSize: Vector2,
    horizontalAlign: "Left" | "Center" | "Right",
    verticalAlign: "Top" | "Center" | "Bottom",
    startCorner: "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight"
}

export type Table = {
    horizontal: boolean,
    sortByName: boolean,
    absoluteContentSize: Vector2,
    horizontalAlign: "Left" | "Center" | "Right",
    verticalAlign: "Top" | "Center" | "Bottom",
    majorAxis: "RowMajor" | "ColumnMajor",
    gap: Utils.Size
}

-- Constraints
export type AspectRatio = {
    ratio: number,
    type: "FitWithinMaxSize" | "ScaleWithParentSize",
    dominantAxis: "Width" | "Height"
}

export type SizeConstraint = {
    max: Vector2,
    min: Vector2
}

export type TextSizeConstraint = {
    max: number,
    min: number
}

export type Scale = {
    scale: number
}

-- Types
type JustList = {
    [string]: any
}

export type Component<Props = JustList> = {
    read _typeName: "modifier",
    read _componentName: string,
    read _uniqueId: number,

    read destroy: () -> (),
    read isDestroyed: () -> boolean,

    read setAnimation: (name: string | number, animation: Animations.MaybeResolvedAnimation?) -> (),
    read getAnimationControl: (name: string | number) -> Animations.AnimationControl,

    read setTransition: <K>(key: K & KeyOf<Props>, transition: Animations.Transition?) -> (),

    read getRef: <K>(key: K & KeyOf<Props>) -> Utils.ProtectedRef<Resolve<Props, K>>,
    read setModifier: <K>(name: string, params: JustList?) -> (),
    read getModifier: <K>(name: string, index: number?) -> Component,

    read setProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    read snapProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    read getProperty: <K>(key: K & KeyOf<Props>) -> Resolve<Props, K>,
    read observe: <K>(key: K & KeyOf<Props>, callback: (newValue: Resolve<Props, K>) -> ()) -> (() -> ()),

    -- Modifiers don't know anything about Space nor Widget
    read getScaleObjectFn: () -> (<T>(value: T, getOriginal: boolean?) -> T),
    read setScaleObjectFn: ((<T>(value: T, getOriginal: boolean?) -> T)?) -> (),

    read _redrawScale: () -> (),
    read _redraw: () -> (),
    read _addCleanup: (RBXScriptConnection | () -> ()) -> (),

    read mountTo: (object: Instance) -> (),
    read getComponent: () -> UIComponent?
}

type Setup<Modifier> = Partial<Modifier> & {
    transitions: {[KeyOf<Modifier>]: Animations.Transition}?,
    animations: {[any]: Animations.Animation}?
}
export type Modifiers = {
    [string]: any?,

    -- Styling
    flex: Setup<Flex>?,
    cornerRadius: Setup<CornerRadius>?,
    padding: Setup<Padding>?,
    stroke: (Setup<Stroke> & { gradient: Setup<Gradient>? })?,
    strokes: {Setup<Stroke> & { gradient: Setup<Gradient>? }}?,
    gradient: Setup<Gradient>?,
    shadow: Setup<Shadow>?,
    shadows: { Setup<Shadow> }?,

    -- Layouts
    list: Setup<List>?,
    grid: Setup<Grid>?,
    table: Setup<Table>?,

    -- Constraints
    aspectRatio: Setup<AspectRatio>?,
    sizeConstraint: Setup<SizeConstraint>?,
    textSizeConstraint: Setup<TextSizeConstraint>?,
    scale: Setup<Scale>?,
}

export type FlexComponent = Component<Flex>
export type CornerRadiusComponent = Component<CornerRadius>
export type PaddingComponent = Component<Padding>
export type StrokeComponent = Component<Stroke>
export type GradientComponent = Component<Gradient>
export type ShadowComponent = Component<Shadow>

export type ListComponent = Component<List>
export type GridComponent = Component<Grid>
export type TableComponent = Component<Table>

export type AspectRatioComponent = Component<AspectRatio>
export type SizeConstraintComponent = Component<SizeConstraint>
export type TextSizeConstraintComponent = Component<TextSizeConstraint>
export type ScaleComponent = Component<Scale>

-- https://github.com/luau-lang/luau/issues/2736
-- Sadly KeyOf/keyof doesn't work for now
export type ComponentNames = "flex"
    | "cornerRadius"
    | "padding"
    | "stroke"
    | "gradient"
    | "shadow"
    | "list"
    | "grid"
    | "table"
    | "aspectRatio"
    | "sizeConstraint"
    | "textSizeConstraint"
    | "scale"

export type Components = {
    [string]: Component,

    -- Styling
    flex: FlexComponent?,
    cornerRadius: CornerRadiusComponent?,
    padding: PaddingComponent?,
    stroke: StrokeComponent?,
    gradient: GradientComponent?,
    shadow: ShadowComponent?,

    -- Layouts
    list: ListComponent?,
    grid: GridComponent?,
    table: TableComponent?,

    -- Constraints
    aspectRatio: AspectRatioComponent?,
    sizeConstraint: SizeConstraintComponent?,
    textSizeConstraint: TextSizeConstraintComponent?,
    scale: ScaleComponent?,
}

return {}
