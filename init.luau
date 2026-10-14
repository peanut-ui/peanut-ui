--!strict
--!optimize 2
const Space = require(script.Classes.Space)
const Component = require(script.Components.Component)
const ControlFlow = require(script.Components.ControlFlow)
const Scaling = require(script.Components.Scaling)
const Widgets = require(script.Components.Widgets)
const State = require(script.State)
const Animations = require(script.Types.Animations)
const Modifier = require(script.Types.Modifier)
const Utils = require(script.Types.Utils)
const WidgetType = require(script.Types.Widget)
const SpaceType = require(script.Types.Space)
const Ref = require(script.Utils.Ref)
const Scheduler = require(script.Utils.Scheduler)
const Units = require(script.Utils.Units)

export type Widget = WidgetType.Interface
export type BaseWidget = WidgetType.BaseInterface
export type WidgetLike = WidgetType.WidgetLike
export type SpaceLike = WidgetType.SpaceLike

export type ScreenSpace = SpaceType.ScreenSpace
export type BillboardSpace = SpaceType.BillboardSpace
export type SurfaceSpace = SpaceType.SurfaceSpace

export type ScreenSpaceProps = SpaceType.ScreenSpaceProps
export type BillboardSpaceProps = SpaceType.BillboardSpaceProps
export type SurfaceSpaceProps = SpaceType.SurfaceSpaceProps

export type SpaceEvents = SpaceType.SpaceEvents

export type Frame = Widgets.Frame
export type CanvasGroup = Widgets.CanvasGroup
export type ImageLabel = Widgets.ImageLabel
export type ImageButton = Widgets.ImageButton
export type TextButton = Widgets.TextButton
export type TextLabel = Widgets.TextLabel
export type TextBox = Widgets.TextBox
export type ScrollingFrame = Widgets.ScrollingFrame
export type ViewportFrame = Widgets.ViewportFrame
export type VideoFrame = Widgets.VideoFrame

export type FrameArgs = Widgets.FrameArgs
export type CanvasGroupArgs = Widgets.CanvasGroupArgs
export type ImageLabelArgs = Widgets.ImageLabelArgs
export type ImageButtonArgs = Widgets.ImageButtonArgs
export type TextButtonArgs = Widgets.TextButtonArgs
export type TextLabelArgs = Widgets.TextLabelArgs
export type TextBoxArgs = Widgets.TextBoxArgs
export type ScrollingFrameArgs = Widgets.ScrollingFrameArgs
export type ViewportFrameArgs = Widgets.ViewportFrameArgs
export type VideoFrameArgs = Widgets.VideoFrameArgs

export type FrameProps = WidgetType.DefaultProperties
export type CanvasGroupProps = Widgets.CanvasGroupProps
export type ImageLabelProps = Widgets.ImageProps
export type ImageButtonProps = Widgets.ImageButtonProps
export type TextButtonProps = Widgets.TextButtonProps
export type TextLabelProps = Widgets.TextProps
export type TextBoxProps = Widgets.TextBoxProps
export type ScrollingFrameProps = Widgets.ScrollingFrameProps
export type ViewportFrameProps = Widgets.ViewportFrameProps
export type VideoFrameProps = Widgets.VideoFrameProps

export type ButtonEvents = Widgets.ButtonEvents
export type VideoFrameEvents = Widgets.VideoFrameEvents

export type DefaultEvents = WidgetType.DefaultEvents
export type WidgetEvents = WidgetType.WidgetEvents

export type Flex = Modifier.FlexComponent
export type CornerRadius = Modifier.CornerRadiusComponent
export type Padding = Modifier.PaddingComponent
export type Stroke = Modifier.StrokeComponent
export type Gradient = Modifier.GradientComponent
export type Shadow = Modifier.ShadowComponent

export type List = Modifier.ListComponent
export type Grid = Modifier.GridComponent
export type Table = Modifier.TableComponent

export type AspectRatio = Modifier.AspectRatioComponent
export type SizeConstraint = Modifier.SizeConstraintComponent
export type TextSizeConstraint = Modifier.TextSizeConstraintComponent
export type Scale = Modifier.ScaleComponent

export type Modifiers = Modifier.Modifiers
export type Components = Modifier.Components

export type Animation = Animations.Animation
export type Transition = Animations.Transition
export type AnimationControl = Animations.AnimationControl
export type AnimationStep = Animations.AnimationStep
export type MaybeResolvedAnimation = Animations.MaybeResolvedAnimation
export type UnresolvedAnimation = Animations.UnresolvedAnimation

export type ProtectedRef<T> = Utils.ProtectedRef<T>
export type SimpleRef<T> = Utils.SimpleRef<T>
export type Ref<T> = Utils.Ref<T>
export type Size = Utils.Size
export type Position = Utils.Position
export type Unit = Utils.Unit

local Components = table.freeze({
    defineComponent = Component.defineComponent,
    onCreated = Component.onCreated,
    onSetup = Component.onSetup,
    onBeforeDestroyed = Component.onBeforeDestroyed,
    onDestroyed = Component.onDestroyed,
    If = ControlFlow.If,
    For = ControlFlow.For,
    ReactiveFor = ControlFlow.ReactiveFor,
    Lazy = ControlFlow.Lazy,
    makeStory = require(script.Components.Stories).makeStory,
})

return table.freeze {
    Logging = require(script.Utils.Logging),
    Scheduler = Scheduler,

    Widgets = Widgets,
    Space = Space,

    Component = Components,

    Animations = require(script.Components.Animations),
    Transitions = require(script.Components.Transitions),

    Scaling = Scaling,
    Undefined = require(script.Utils.Undefined),

    Ref = Ref,
    Units = Units,
    State = State,

    -- Units shortcuts
    Position = Units.Position,
    Size = Units.Size,
    Unit = Units.Unit,
    PositionFromUDim2 = Units.PositionFromUDim2,
    UnitFromUDim = Units.UnitFromUDim,
    ToUDim2 = Units.ToUDim2,
    ToUDim = Units.ToUDim,

    -- Misc shortcuts
    simpleScale = Scaling.simpleScale,

    -- Space shortcuts
    createBillboardSpace = Space.createBillboardSpace,
    createScreenSpace = Space.createScreenSpace,
    createSurfaceSpace = Space.createSurfaceSpace,
    getBillboardSpace = Space.getBillboardSpace,
    getScreenSpace = Space.getScreenSpace,
    getSurfaceSpace = Space.getSurfaceSpace,

    -- Widget shortcuts
    Frame = Widgets.Frame,
    CanvasGroup = Widgets.CanvasGroup,
    ScrollingFrame = Widgets.ScrollingFrame,
    ImageLabel = Widgets.ImageLabel,
    ImageButton = Widgets.ImageButton,
    TextLabel = Widgets.TextLabel,
    TextButton = Widgets.TextButton,
    TextBox = Widgets.TextBox,
    ViewportFrame = Widgets.ViewportFrame,
    VideoFrame = Widgets.VideoFrame,

    -- Component shortcuts
    defineComponent = Component.defineComponent,
    onCreated = Component.onCreated,
    onSetup = Component.onSetup,
    onBeforeDestroyed = Component.onBeforeDestroyed,
    onDestroyed = Component.onDestroyed,
    If = ControlFlow.If,
    For = ControlFlow.For,
    ReactiveFor = ControlFlow.ReactiveFor,
    Lazy = ControlFlow.Lazy,
    makeStory = require(script.Components.Stories).makeStory,

    -- Info
    version = State.Version,
    versionString = State.VersionString,
    preferredInput = State.preferredInput,
    globalSignals = State.signals,

    -- Ref shortcuts
    ref = Ref.new,
    computed = Ref.computed,
    getRef = Ref.getRef,
    toRef = Ref.toRef,
    isRef = Ref.isRef,
    reactive = Ref.reactive,
    isEqual = Ref.isEqual,

    -- Scheduler shortcuts
    defer = Scheduler.defer,
    settled = Scheduler.settled,
    idle = Scheduler.idle,
    waitFor = Scheduler.waitFor,
}