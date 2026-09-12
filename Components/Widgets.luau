--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Classes.Widget)
const WidgetClass = require(script.Parent.Parent.Types.Widget)
const State = require(script.Parent.Parent.State)
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)

export type Flatten<Table> = TypeFuncs.Flatten<Table>
local defaultFontFace = Font.new("rbxasset://fonts/families/Roboto.json")

export type CreateFn<
    Object = GuiObject,
    Props = WidgetClass.DefaultProperties,
    Events = WidgetClass.DefaultEvents
> = (
    (WidgetClass.Args<Props, Object, Events>?) -> WidgetClass.Interface<Props, Object, Events>
)

export type CanvasGroupProps = Flatten<{
    groupColor: Color3,
    groupTransparency: number,
    selectionImageObject: GuiObject?
} & WidgetClass.DefaultProperties>

export type ImageProps = Flatten<{
    image: string,
    imageColor: Color3,
    imageTransparency: number,
    resampleMode: Enum.ResamplerMode,
    scaleType: Enum.ScaleType,
    sliceCenter: Rect,
    sliceScale: number,
    tileSize: UDim2,
    imageRectOffset: Vector2,
    imageRectSize: Vector2,
} & WidgetClass.DefaultProperties>

export type ImageButtonProps = Flatten<{
    hoverImage: string,
    pressedImage: string,
    autoButtonColor: boolean,
    modal: boolean,
    selected: boolean,
} & ImageProps>

export type TextProps = Flatten<{
    text: string,
    textColor: Color3,
    textTransparency: number,
    textStrokeColor: Color3,
    textStrokeTransparency: number,
    fontFace: Font,
    textSize: number,
    textScaled: boolean,
    textWrapped: boolean,
    textXAlignment: Enum.TextXAlignment,
    textYAlignment: Enum.TextYAlignment,
    richText: boolean,
    lineHeight: number,
    maxVisibleGraphemes: number,
    textTruncate: Enum.TextTruncate,
} & WidgetClass.DefaultProperties>

export type TextButtonProps = Flatten<{
    autoButtonColor: boolean,
    modal: boolean,
    selected: boolean,
    style: Enum.ButtonStyle,
} & TextProps>

export type TextBoxProps = Flatten<{
    clearTextOnFocus: boolean,
    multiLine: boolean,
    placeholderText: string,
    placeholderColor: Color3,
    cursorPosition: number,
    selectionStart: number,
} & TextProps>

export type ScrollingFrameProps = Flatten<{
    canvasPosition: Vector2,
    canvasSize: UDim2,
    automaticCanvasSize: Enum.AutomaticSize,
    scrollingDirection: Enum.ScrollingDirection,
    scrollingEnabled: boolean,
    scrollBarImageColor: Color3,
    scrollBarImageTransparency: number,
    scrollBarThickness: number,
    verticalScrollBarInset: Enum.ScrollBarInset,
    horizontalScrollBarInset: Enum.ScrollBarInset,
    elasticBehavior: Enum.ElasticBehavior,
} & WidgetClass.DefaultProperties>

export type ViewportFrameProps = Flatten<{
    currentCamera: Camera?,
    imageColor: Color3,
    imageTransparency: number,
    ambient: Color3,
    lightColor: Color3,
    lightDirection: Vector3,
} & WidgetClass.DefaultProperties>

export type VideoFrameProps = Flatten<{
    video: string,
    playing: boolean,
    looped: boolean,
    volume: number,
    timePosition: number,
    playbackSpeed: number,
    imageColor: Color3,
    imageTransparency: number,
} & WidgetClass.DefaultProperties>

export type ButtonEvents = Flatten<{
    Activated: (obj: InputObject, clickCount: number) -> (),
    SecondaryActivated: (obj: InputObject) -> ()
} & WidgetClass.DefaultEvents>

local function linkProperties(
    widget: WidgetClass.Interface,
    properties: {[string]: string},
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: boolean?}?
)
    local link = (widget :: WidgetClass.InternalInterface)._linkProperty
    for name, property in properties do
        link(
            name :: any, property,
            transformFn and transformFn[name],
            syncWithObject and syncWithObject[name]
        )
    end
end

local function createBasicObject<T>(
    widgetName: string,
    defaultProperties: T & {[string]: any},
    createFn: () -> any,
    linkedProperties: {[string]: string}?,
    linkEvents: {string}?,
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: boolean?}?,
    setupFn: (any) -> ()?
): (WidgetClass.Args) -> WidgetClass.Interface
    return function(args)
        local argsCopy = table.clone(args)

        local function setup(widget: any, defaultSetup)
            defaultSetup(widget)
            widget.createObject = createFn

            if linkedProperties then
                linkProperties(widget, linkedProperties, transformFn, syncWithObject)
            end
            if setupFn then
                setupFn(widget)
            end

            if linkEvents then
                for _, eventName in ipairs(linkEvents) do
                    widget._linkEvent(eventName)
                end
            end
        end

        local originalOverride = argsCopy.defaultSetupOverride
        argsCopy.defaultSetupOverride = function(widget: any, defaultSetup)
            if originalOverride then
                originalOverride(widget, setup)
                return
            end

            setup(widget, defaultSetup)
        end

        local properties = table.clone(defaultProperties)
        if argsCopy.properties then
            for key, value in pairs(argsCopy.properties :: any) do
                properties[key] = value
            end
        end

        argsCopy.properties = properties
        if not argsCopy.widgetName then
            argsCopy.widgetName = widgetName
        end

        return Widget.new(argsCopy)
    end
end

return {
    Frame = createBasicObject(
        "frame",
        {
            name = "Frame"
        },
        function()
            return Instance.new("Frame")
        end, nil
    ) :: CreateFn<Frame>,
    CanvasGroup = createBasicObject(
        "canvasGroup",
        {
            groupColor = Color3.new(1, 1, 1),
            groupTransparency = 0,
        },
        function()
            return Instance.new("CanvasGroup")
        end,
        {
            groupColor = "GroupColor",
            groupTransparency = "GroupTransparency",
            selectionImageObject = "SelectionImageObject",
        }
    ) :: CreateFn<CanvasGroup, CanvasGroupProps>,
    ImageLabel = createBasicObject(
        "imageLabel",
        {
            name = "ImageLabel",
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
            resampleMode = Enum.ResamplerMode.Default,
            scaleType = Enum.ScaleType.Stretch,
            sliceScale = 1,
        },
        function()
            return Instance.new("ImageLabel")
        end,
        {
            image = "Image",
            imageColor = "ImageColor3",
            imageTransparency = "ImageTransparency",
            resampleMode = "ResampleMode",
            scaleType = "ScaleType",
            sliceCenter = "SliceCenter",
            sliceScale = "SliceScale",
            tileSize = "TileSize",
            imageRectOffset = "ImageRectOffset",
            imageRectSize = "ImageRectSize",
        }
    ) :: CreateFn<ImageLabel, ImageProps>,
    ImageButton = createBasicObject(
        "imageButton",
        {
            name = "ImageButton",
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
            resampleMode = Enum.ResamplerMode.Default,
            scaleType = Enum.ScaleType.Stretch,
            sliceScale = 1,
            autoButtonColor = true,
            modal = false,
            selected = false,
        },
        function()
            return Instance.new("ImageButton")
        end,
        {
            image = "Image",
            imageColor = "ImageColor3",
            imageTransparency = "ImageTransparency",
            hoverImage = "HoverImage",
            pressedImage = "PressedImage",
            resampleMode = "ResampleMode",
            scaleType = "ScaleType",
            sliceCenter = "SliceCenter",
            sliceScale = "SliceScale",
            tileSize = "TileSize",
            imageRectOffset = "ImageRectOffset",
            imageRectSize = "ImageRectSize",
            autoButtonColor = "AutoButtonColor",
            modal = "Modal",
            selected = "Selected",
        },
        {"Activated", "SecondaryActivated"},
        { tileSize = State.scaleUDim2 },
        { selected = true }
    ) :: CreateFn<ImageButton, ImageButtonProps, ButtonEvents>,
    ScrollingFrame = createBasicObject(
        "scrollingFrame",
        {
            name = "ScrollingFrame",
            canvasPosition = Vector2.new(0, 0),
            canvasSize = UDim2.new(0, 0, 0, 0),
            automaticCanvasSize = Enum.AutomaticSize.None,
            scrollingDirection = Enum.ScrollingDirection.Y,
            scrollingEnabled = true,
            scrollBarImageColor = Color3.new(0, 0, 0),
            scrollBarImageTransparency = 0.5,
            scrollBarThickness = 12,
            verticalScrollBarInset = Enum.ScrollBarInset.None,
            horizontalScrollBarInset = Enum.ScrollBarInset.None,
            elasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        },
        function()
            return Instance.new("ScrollingFrame")
        end,
        {
            canvasPosition = "CanvasPosition",
            canvasSize = "CanvasSize",
            automaticCanvasSize = "AutomaticCanvasSize",
            scrollingDirection = "ScrollingDirection",
            scrollingEnabled = "ScrollingEnabled",
            scrollBarImageColor = "ScrollBarImageColor3",
            scrollBarImageTransparency = "ScrollBarImageTransparency",
            scrollBarThickness = "ScrollBarThickness",
            verticalScrollBarInset = "VerticalScrollBarInset",
            horizontalScrollBarInset = "HorizontalScrollBarInset",
            elasticBehavior = "ElasticBehavior",
        },
        nil,
        nil,
        { canvasPosition = true }
    ) :: CreateFn<ScrollingFrame, ScrollingFrameProps>,
    TextLabel = createBasicObject(
        "textLabel",
        {
            name = "TextLabel",
            text = "Label",
            textColor = Color3.new(1, 1, 1),
            textTransparency = 0,
            textStrokeColor = Color3.new(0, 0, 0),
            textStrokeTransparency = 1,
            fontFace = defaultFontFace,
            textSize = 14,
            textScaled = false,
            textWrapped = false,
            textXAlignment = Enum.TextXAlignment.Center,
            textYAlignment = Enum.TextYAlignment.Center,
            richText = false,
            lineHeight = 1,
            maxVisibleGraphemes = -1,
            textTruncate = Enum.TextTruncate.None
        },
        function()
            return Instance.new("TextLabel")
        end,
        {
            text = "Text",
            textColor = "TextColor3",
            textTransparency = "TextTransparency",
            textStrokeColor = "TextStrokeColor3",
            textStrokeTransparency = "TextStrokeTransparency",
            fontFace = "FontFace",
            textSize = "TextSize",
            textScaled = "TextScaled",
            textWrapped = "TextWrapped",
            textXAlignment = "TextXAlignment",
            textYAlignment = "TextYAlignment",
            richText = "RichText",
            lineHeight = "LineHeight",
            maxVisibleGraphemes = "MaxVisibleGraphemes",
            textTruncate = "TextTruncate"
        },
        nil,
        nil,
        {
            textSize = State.scalePx,
        }
    ) :: CreateFn<TextLabel, TextProps>,
    TextButton = createBasicObject(
        "textButton",
        {
            name = "TextButton",
            text = "Button",
            textColor = Color3.new(1, 1, 1),
            textTransparency = 0,
            textStrokeColor = Color3.new(0, 0, 0),
            textStrokeTransparency = 1,
            fontFace = defaultFontFace,
            textSize = 14,
            textScaled = false,
            textWrapped = false,
            textXAlignment = Enum.TextXAlignment.Center,
            textYAlignment = Enum.TextYAlignment.Center,
            richText = false,
            lineHeight = 1,
            maxVisibleGraphemes = -1,
            textTruncate = Enum.TextTruncate.None,
            autoButtonColor = true,
            modal = false,
            selected = false,
            style = Enum.ButtonStyle.Custom
        },
        function()
            return Instance.new("TextButton")
        end,
        {
            text = "Text",
            textColor = "TextColor3",
            textTransparency = "TextTransparency",
            textStrokeColor = "TextStrokeColor3",
            textStrokeTransparency = "TextStrokeTransparency",
            fontFace = "FontFace",
            textSize = "TextSize",
            textScaled = "TextScaled",
            textWrapped = "TextWrapped",
            textXAlignment = "TextXAlignment",
            textYAlignment = "TextYAlignment",
            richText = "RichText",
            lineHeight = "LineHeight",
            maxVisibleGraphemes = "MaxVisibleGraphemes",
            textTruncate = "TextTruncate",
            autoButtonColor = "AutoButtonColor",
            modal = "Modal",
            selected = "Selected",
            style = "Style"
        },
        {"Activated", "SecondaryActivated"},
        {
            textSize = State.scalePx,
        }
    ) :: CreateFn<TextButton, TextButtonProps, ButtonEvents>,
    TextBox = createBasicObject(
        "textBox",
        {
            name = "TextBox",
            text = "",
            textColor = Color3.new(1, 1, 1),
            textTransparency = 0,
            textStrokeColor = Color3.new(0, 0, 0),
            textStrokeTransparency = 1,
            fontFace = defaultFontFace,
            textSize = 14,
            textScaled = false,
            textWrapped = false,
            textXAlignment = Enum.TextXAlignment.Left,
            textYAlignment = Enum.TextYAlignment.Top,
            richText = false,
            lineHeight = 1,
            maxVisibleGraphemes = -1,
            textTruncate = Enum.TextTruncate.None,
            clearTextOnFocus = false,
            multiLine = false,
            placeholderText = "",
            placeholderColor = Color3.new(0.5, 0.5, 0.5),
            cursorPosition = 0,
            selectionStart = 0,
        },
        function()
            return Instance.new("TextBox")
        end,
        {
            text = "Text",
            textColor = "TextColor3",
            textTransparency = "TextTransparency",
            textStrokeColor = "TextStrokeColor3",
            textStrokeTransparency = "TextStrokeTransparency",
            fontFace = "FontFace",
            textSize = "TextSize",
            textScaled = "TextScaled",
            textWrapped = "TextWrapped",
            textXAlignment = "TextXAlignment",
            textYAlignment = "TextYAlignment",
            richText = "RichText",
            lineHeight = "LineHeight",
            maxVisibleGraphemes = "MaxVisibleGraphemes",
            textTruncate = "TextTruncate",
            clearTextOnFocus = "ClearTextOnFocus",
            multiLine = "MultiLine",
            placeholderText = "PlaceholderText",
            placeholderColor = "PlaceholderColor3",
            cursorPosition = "CursorPosition",
            selectionStart = "SelectionStart",
        },
        nil,
        {
            textSize = State.scalePx,
        },
        {
            cursorPosition = true,
            selectionStart = true
        }
    ) :: CreateFn<TextBox, TextBoxProps>,
    ViewportFrame = createBasicObject(
        "viewportFrame",
        {
            name = "ViewportFrame",
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
            ambient = Color3.new(1, 1, 1),
            lightColor = Color3.new(1, 1, 1),
            lightDirection = Vector3.new(0, 1, -1),
        },
        function()
            return Instance.new("ViewportFrame")
        end,
        {
            currentCamera = "CurrentCamera",
            imageColor = "ImageColor3",
            imageTransparency = "ImageTransparency",
            ambient = "Ambient",
            lightColor = "LightColor",
            lightDirection = "LightDirection",
        }
    ) :: CreateFn<ViewportFrame, ViewportFrameProps>,
    VideoFrame = createBasicObject(
        "videoFrame",
        {
            name = "VideoFrame",
            playing = false,
            looped = true,
            volume = 1,
            timePosition = 0,
            playbackSpeed = 1,
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
        },
        function()
            return Instance.new("VideoFrame")
        end,
        {
            video = "Video",
            playing = "Playing",
            looped = "Looped",
            volume = "Volume",
            timePosition = "TimePosition",
            playbackSpeed = "PlaybackSpeed",
            imageColor = "ImageColor3",
            imageTransparency = "ImageTransparency",
        },
        nil,
        nil,
        {
            playing = true,
            timePosition = true
        }
    ) :: CreateFn<VideoFrame, VideoFrameProps>,
}