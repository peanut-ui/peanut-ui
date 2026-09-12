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
    topLeftScale: number?,
    topRightScale: number?,
    bottomLeftScale: number?,
    bottomRightScale: number?,
    topLeftPx: number?,
    topRightPx: number?,
    bottomLeftPx: number?,
    bottomRightPx: number?,
    px: number,
    scale: number
}

export type Padding = {
    leftScale: number?,
    rightScale: number?,
    topScale: number?,
    bottomScale: number?,
    topPx: number?,
    bottomPx: number?,
    leftPx: number?,
    rightPx: number?,
    px: number,
    scale: number
}

export type Stroke = {
    enabled: boolean,
    zIndex: number,
    color: Color3,
    transparency: number,
    thicknessPx: number,
    borderOffsetScale: number,
    borderOffsetPx: number,
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
    blurRadiusPx: number,
    blurRadiusScale: number,
    color: Color3,
    offset: Utils.Position,
    spread: Utils.Size,
    transparency: number,
    zIndex: number
}

-- Layouts
export type List = {
    gapPx: number?,
    gapScale: number?,
    horizontal: boolean?,
    sortByName: boolean?,
    wraps: boolean?,
    horizontalAlign: "Left" | "Center" | "Right"?,
    verticalAlign: "Top" | "Center" | "Bottom"?,
    horizontalFlex: "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly"?,
    itemLineAlign: "Auto" | "Center" | "End" | "Start" | "Stretch"?,
}

export type Grid = {
    cellPaddingPx: Vector2?,
    cellPaddingScale: Vector2?,
    cellSizePx: Vector2?,
    cellSizeScale: Vector2?,
    fillDirection: "Horizontal" | "Vertical"?,
    fillDirectionMaxCells: number?,
    horizontalAlign: "Left" | "Center" | "Right"?,
    verticalAlign: "Top" | "Center" | "Bottom"?,
    sortOrder: "LayoutOrder" | "Name" | "Custom"?,
    startCorner: "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight"?
}

export type TableLayout = {
    fillDirection: "Horizontal" | "Vertical"?,
    horizontalAlign: "Left" | "Center" | "Right"?,
    verticalAlign: "Top" | "Center" | "Bottom"?,
    sortOrder: "LayoutOrder" | "Name" | "Custom"?,
    majorAxis: "RowMajor" | "ColumnMajor"?,
    paddingPx: Vector2?,
    paddingScale: Vector2?
}

-- Constraints
export type AspectRatio = {
    ratio: number?,
    type: "FitWithinMaxSize" | "ScaleWithParentSize"?,
    dominantAxis: "Width" | "Height"?
}

export type SizeConstraint = {
    max: Vector2?,
    min: Vector2?
}

export type TextSizeConstraint = {
    max: number?,
    min: number?
}

export type Scale = {
    scale: number?
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

    read setTransition: <K>(key: K & KeyOf<Props>, transition: Animations.Transition?) -> (),

    read setProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    read snapProperty: <K>(key: K & KeyOf<Props>, value: Resolve<Props, K> | Utils.Ref<Resolve<Props, K>>) -> (),
    read getProperty: <K>(key: K & KeyOf<Props>) -> Resolve<Props, K>,
    read observe: <K>(key: K & KeyOf<Props>, callback: (newValue: Resolve<Props, K>) -> ()) -> (() -> ()),

    read _redraw: () -> (),
    read _addCleanup: (RBXScriptConnection | () -> ()) -> (),

    read mountTo: (object: Instance) -> (),
    read getComponent: () -> UIComponent?
}

export type Modifiers = {
    [string]: any?,

    -- Styling
    flex: Partial<Flex>?,
    cornerRadius: Partial<CornerRadius>?,
    padding: Partial<Padding>?,
    stroke: Partial<Stroke>?,
    gradient: Partial<Gradient>?,
    shadow: Partial<Shadow>?,
    shadows: {Partial<Shadow>}?,

    -- Layouts
    list: Partial<List>?,
    grid: Partial<Grid>?,
    tableLayout: Partial<TableLayout>?,

    -- Constraints
    aspectRatio: Partial<AspectRatio>?,
    sizeConstraint: Partial<SizeConstraint>?,
    textSizeConstraint: Partial<TextSizeConstraint>?,
    scale: Partial<Scale>?,
}

export type Components = {
    [string]: Component,

    -- Styling
    flex: Component<Flex>?,
    cornerRadius: Component<CornerRadius>?,
    padding: Component<Padding>?,
    stroke: Component<Stroke>?,
    gradient: Component<Gradient>?,
    shadow: Component<Shadow>?,

    -- Layouts
    list: Component<List>?,
    grid: Component<Grid>?,
    tableLayout: Component<TableLayout>?,

    -- Constraints
    aspectRatio: Component<AspectRatio>?,
    sizeConstraint: Component<SizeConstraint>?,
    textSizeConstraint: Component<TextSizeConstraint>?,
    scale: Component<Scale>?,
}

return {}
