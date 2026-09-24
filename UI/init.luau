--!strict
--!optimize 2
const Component = require(script.Components.Component)
const ControlFlow = require(script.Components.ControlFlow)
const Widgets = require(script.Components.Widgets)
const Modifier = require(script.Types.Modifier)
const Utils = require(script.Types.Utils)
const WidgetType = require(script.Types.Widget)
const Ref = require(script.Utils.Ref)
const Scheduler = require(script.Utils.Scheduler)

export type Widget = WidgetType.Interface
export type BaseWidget = WidgetType.BaseInterface

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
    makeStory = require(script.Components.Stories).makeStory,
})

return table.freeze {
    Logging = require(script.Utils.Logging),

    Widgets = Widgets,
    Space = require(script.Classes.Space),

    Component = Components,

    Animations = require(script.Components.Animations),
    Transitions = require(script.Components.Transitions),

    Undefined = require(script.Utils.Undefined),

    Ref = Ref,
    Units = require(script.Utils.Units),
    State = require(script.State),

    -- Ref shortcuts
    ref = Ref.new,
    computed = Ref.computed,
    transform = Ref.transform,
    getRef = Ref.getRef,
    toRef = Ref.toRef,
    isRef = Ref.isRef,
    reactive = Ref.reactive,
    swap = Ref.swap,
    deepSwap = Ref.deepSwap,

    -- Scheduler shortcuts
    defer = Scheduler.defer,
    settled = Scheduler.settled,
    idle = Scheduler.idle,
    waitFor = Scheduler.waitFor,
}