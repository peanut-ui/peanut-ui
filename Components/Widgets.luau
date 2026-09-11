--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Classes.Widget)
const WidgetClass = require(script.Parent.Parent.Types.Widget)
const State = require(script.Parent.Parent.State)

export type CreateFn<
    Object = GuiObject,
    Props = WidgetClass.DefaultProperties,
    Events = WidgetClass.DefaultEvents
> = (
    (WidgetClass.Args<Props, Object, Events>?) -> WidgetClass.Interface<Props, Object, Events>
)

export type CanvasGroupProps = WidgetClass.DefaultProperties & {
    groupColor: Color3,
    groupTransparency: number,
    selectionImageObject: GuiObject?
}

export type ImageProps = WidgetClass.DefaultProperties & {
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
}

export type ImageButtonProps = ImageProps & {
    hoverImage: string,
    pressedImage: string,
    autoButtonColor: boolean,
    modal: boolean,
    selected: boolean,
}

export type TextProps = WidgetClass.DefaultProperties & {
    text: string,
    textColor: Color3,
    textTransparency: number,
    textStrokeColor: Color3,
    textStrokeTransparency: number,
    font: Enum.Font,
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
}

export type TextButtonProps = TextProps & {
    autoButtonColor: boolean,
    modal: boolean,
    selected: boolean,
    style: Enum.ButtonStyle,
}

export type TextBoxProps = TextProps & {
    clearTextOnFocus: boolean,
    multiLine: boolean,
    placeholderText: string,
    placeholderColor: Color3,
    cursorPosition: number,
    selectionStart: number,
}

export type ScrollingFrameProps = WidgetClass.DefaultProperties & {
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
}

export type ViewportFrameProps = WidgetClass.DefaultProperties & {
    currentCamera: Camera?,
    imageColor: Color3,
    imageTransparency: number,
    ambient: Color3,
    lightColor: Color3,
    lightDirection: Vector3,
}

export type VideoFrameProps = WidgetClass.DefaultProperties & {
    video: string,
    playing: boolean,
    looped: boolean,
    volume: number,
    timePosition: number,
    playbackSpeed: number,
    imageColor: Color3,
    imageTransparency: number,
}

export type ButtonEvents = {
    Activated: (obj: InputObject, clickCount: number) -> (),
    SecondaryActivated: (obj: InputObject) -> ()
} & WidgetClass.DefaultEvents

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
            transformFn and transformFn[property],
            syncWithObject and syncWithObject[property]
        )
    end
end

local function createBasicObject<T>(
    widgetName: string,
    defaultProperties: T & {[string]: any},
    createFn: () -> any,
    linkedProperties: {[string]: string}?,
    setupFn: (any) -> ()?,
    linkEvents: {string}?,
    transformFn: {[string]: (any) -> any}?,
    syncWithObject: {[string]: boolean?}?
): (WidgetClass.Args) -> WidgetClass.Interface
    return function(args)
        local argsCopy = table.clone(args)

        local originalOnSetup = argsCopy.onSetup
        argsCopy.onSetup = function(widget)
            widget.createObject = createFn

            if linkedProperties then
                linkProperties(widget, linkedProperties)
            end

            if setupFn then
                setupFn(widget)
            end
            if originalOnSetup then
                originalOnSetup(widget)
            end

            if linkEvents then
                for _, eventName in ipairs(linkEvents) do
                    widget._linkEvent(eventName)
                end
            end
        end

        local properties = table.clone(defaultProperties)
        if args.properties then
            for key, value in pairs(args.properties) do
                properties[key] = value
            end
        end

        args.properties = properties
        if not args.widgetName then
            args.widgetName = widgetName
        end

        return Widget.new(args)
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
        nil,
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
            font = Enum.Font.Gotham,
            textSize = 14,
            textScaled = false,
            textWrapped = false,
            textXAlignment = Enum.TextXAlignment.Center,
            textYAlignment = Enum.TextYAlignment.Center,
            richText = false,
            lineHeight = 1,
            maxVisibleGraphemes = -1,
            textTruncate = Enum.TextTruncate.None,
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
            font = "Font",
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
            font = Enum.Font.Gotham,
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
            font = "Font",
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
            style = "Style",
        },
        nil,
        {"Activated", "SecondaryActivated"},
        {
            textSize = State.scalePx
        },
        { selected = true }
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
            font = Enum.Font.Gotham,
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
            font = "Font",
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
        nil,
        nil,
        {
            cursorPosition = true,
            selectionStart = true,
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
        nil,
        {
            playing = true,
            timePosition = true
        }
    ) :: CreateFn<VideoFrame, VideoFrameProps>,
}