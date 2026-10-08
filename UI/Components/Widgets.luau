--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Classes.Widget)
const WidgetClass = require(script.Parent.Parent.Types.Widget)
const RobloxTypes = require(script.Parent.Parent.Types.RobloxTypes)
const TypeFuncs = require(script.Parent.Parent.Types.TypeFuncs)
const Utils = require(script.Parent.Parent.Types.Utils)
const Helpers = require(script.Parent.Parent.Utils.Helpers)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Undefined = require(script.Parent.Parent.Utils.Undefined)
const Units = require(script.Parent.Parent.Utils.Units)

local logger = Logging.getLogger("PeanutUI.Components.Widget")

export type Flatten<Table> = TypeFuncs.Flatten<Table>
local defaultFontFace = Font.new("rbxasset://fonts/families/Roboto.json")

export type CanvasGroupProps = Flatten<{
    groupColor: Color3,
    groupTransparency: number,
} & WidgetClass.DefaultProperties>

export type ImageProps = Flatten<{
    imageContent: Content,
    imageColor: Color3,
    imageTransparency: number,
    resampleMode: Enum.ResamplerMode,
    scaleType: Enum.ScaleType,
    sliceCenter: Rect,
    sliceScale: number,
    tileSize: Utils.Size,
    imageRectOffset: Vector2,
    imageRectSize: Vector2,
    isLoaded: boolean,
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
    canvasSize: Utils.Size,
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

-- {"DidLoop", "Ended", "Loaded", "Paused", "Played"},
type VideoFrameEvent = (video: string) -> ...boolean?
export type VideoFrameEvents = Flatten<{
    DidLoop: VideoFrameEvent,
    Ended: VideoFrameEvent,
    Loaded: VideoFrameEvent,
    Paused: VideoFrameEvent,
    Played: VideoFrameEvent
} & WidgetClass.DefaultEvents>

export type Frame = WidgetClass.Interface<WidgetClass.DefaultProperties, RobloxTypes.FrameObject>
export type FrameArgs = WidgetClass.Args<WidgetClass.DefaultProperties, Frame>

export type CanvasGroup = WidgetClass.Interface<CanvasGroupProps, RobloxTypes.CanvasGroupObject>
export type CanvasGroupArgs = WidgetClass.Args<CanvasGroupProps, CanvasGroup>

export type ImageLabel = WidgetClass.Interface<ImageProps, RobloxTypes.ImageLabelObject>
export type ImageLabelArgs = WidgetClass.Args<ImageProps, ImageLabel>

export type ImageButton = WidgetClass.Interface<ImageButtonProps, RobloxTypes.ImageButtonObject, ButtonEvents>
export type ImageButtonArgs = WidgetClass.Args<ImageButtonProps, ImageButton, ButtonEvents>

export type TextButton = WidgetClass.Interface<TextButtonProps, RobloxTypes.TextButtonObject, ButtonEvents>
export type TextButtonArgs = WidgetClass.Args<TextButtonProps, TextButton, ButtonEvents>

export type TextLabel = WidgetClass.Interface<TextProps, RobloxTypes.TextLabelObject>
export type TextLabelArgs = WidgetClass.Args<TextProps, TextLabel>

export type TextBox = WidgetClass.Interface<TextBoxProps, RobloxTypes.TextBoxObject>
export type TextBoxArgs = WidgetClass.Args<TextBoxProps, TextBox>

export type ScrollingFrame = WidgetClass.Interface<ScrollingFrameProps, RobloxTypes.ScrollingFrameObject>
export type ScrollingFrameArgs = WidgetClass.Args<ScrollingFrameProps, ScrollingFrame>

export type ViewportFrame = WidgetClass.Interface<ViewportFrameProps, RobloxTypes.ViewportFrameObject>
export type ViewportFrameArgs = WidgetClass.Args<ViewportFrameProps, ViewportFrame>

export type VideoFrame = WidgetClass.Interface<VideoFrameProps, RobloxTypes.VideoFrameObject, VideoFrameEvents>
export type VideoFrameArgs = WidgetClass.Args<VideoFrameProps, VideoFrame, VideoFrameEvents>

export type Children = {WidgetClass.WidgetLike}

type Converter = {
    toUDim2: (any) -> UDim2,
    fromUDim2: (any) -> any,
}
type ScaleType = "scale" | "scaleToUDim2" | "scaleToSize" | "scaleToPos"

local converters: {[ScaleType]: Converter} = {
    scale = {
        toUDim2 = function(v) return v end,
        fromUDim2 = function(v) return v end,
    },
    scaleToUDim2 = {
        toUDim2 = Units.ToUDim2,
        fromUDim2 = function(v) return v end,
    },
    scaleToSize = {
        toUDim2 = Units.ToUDim2,
        fromUDim2 = Units.SizeFromUDim2,
    },
    scaleToPos = {
        toUDim2 = Units.ToUDim2,
        fromUDim2 = Units.PositionFromUDim2,
    },
}


local function makeScale(type: ScaleType, getOriginal: boolean?)
    local converter = converters[type]
    if not converter then
        error(`Unknown scale type, got: {type}`, 2)
    end

    return function(widget: WidgetClass.Interface, value: any): any
        local space = widget.getSpace()
        if not space then
            return converter.fromUDim2(converter.toUDim2(value))
        end

        return converter.fromUDim2(space.scaleObject(converter.toUDim2(value), getOriginal))
    end
end

local function linkProperties(
    widget: WidgetClass.Interface,
    properties: {[string]: string},
    transformFn: {[string]: ((WidgetClass.WidgetLike, any) -> any)}?,
    syncWithObject: {[string]: (boolean | (WidgetClass.WidgetLike, any) -> any)?}?,
    readonly: {[string]: boolean?}?,
    redrawOnHooks: {[string]: {string}}?
)
    local link = (widget :: WidgetClass.InternalInterface)._linkProperty
    for name, property in properties do
        link(
            name :: any,
            property,
            transformFn and transformFn[name],
            syncWithObject and syncWithObject[name],
            readonly and readonly[name],
            redrawOnHooks and redrawOnHooks[name]
        )
    end
end

local function freeze(obj: {[any]: any}?)
    if obj then table.freeze(obj) end
end

-- Idk what name to choose
local function constructSyncList(
    transform: {[any]: any},
    transformNew: {[any]: any},
    redrawOnHooksNew: {[any]: any},
    getOriginal: boolean?
)
    if transform then
        for name, obj in transform do
            if typeof(obj) ~= "string" then
                transformNew[name] = obj
                continue
            end

            local converter = converters[obj]
            if converter then
                transformNew[name] = makeScale(obj :: ScaleType, getOriginal)
                if not redrawOnHooksNew then
                    redrawOnHooksNew = {[name] = {"ScaleChanged"}}
                else
                    if not redrawOnHooksNew[name] then
                        redrawOnHooksNew[name] = {"ScaleChanged"}
                    elseif not table.find(redrawOnHooksNew[name], "ScaleChanged") then
                        table.insert(redrawOnHooksNew[name], "ScaleChanged")
                    end
                end
            end
        end
    end
end

local function createBasicObject(
    widgetName: string,
    defaultProperties: {[string]: any | () -> any},
    createFn: () -> any,
    linkedProperties: {[string]: string}?,
    linkEvents: {string}?,
    transformFn: {[string]: ((WidgetClass.WidgetLike, any) -> any) | ScaleType}?,
    syncWithObject: {[string]: (boolean | ScaleType | (WidgetClass.WidgetLike, any) -> any)?}?,
    readonly: {[string]: boolean?}?,
    redrawOnHooks: {[string]: {string}}?,
    setupFn: (any) -> ()?
): (WidgetClass.Args?, Children?) -> WidgetClass.Interface
    table.freeze(defaultProperties)
    freeze(linkedProperties)
    freeze(linkEvents)
    freeze(transformFn)
    freeze(syncWithObject)
    freeze(readonly)
    freeze(redrawOnHooks)

    -- Process them here so linkProperties is kept small
    local transformFnNew: {[string]: ((any) -> any)} = {}
    local syncWithObjectNew: {[string]: (boolean | (any) -> any)?} = {}
    local redrawOnHooksNew = redrawOnHooks and table.clone(redrawOnHooks) or {}

    constructSyncList(transformFn, transformFnNew, redrawOnHooksNew)
    constructSyncList(syncWithObject, syncWithObjectNew, redrawOnHooksNew, true)

    table.freeze(syncWithObjectNew)
    table.freeze(transformFnNew)
    table.freeze(redrawOnHooksNew)

    return function(args, children)
        local argsCopy: WidgetClass.Args = args and table.clone(args) or {}
        if children then
            if argsCopy.children then
                logger.error("Cannot have args.children and children as second argument at the same time")
            end
            argsCopy.children = children
        end

        local function setup(widget: any, defaultSetup)
            defaultSetup(widget)
            widget._setCreateObject(createFn)

            if linkedProperties then
                linkProperties(
                    widget,
                    linkedProperties,
                    transformFnNew,
                    syncWithObjectNew,
                    readonly,
                    redrawOnHooksNew
                )
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

        local originalOverride = Helpers.removeUndefined(argsCopy.defaultSetupOverride)
        argsCopy.defaultSetupOverride = function(widget: any, defaultSetup)
            if originalOverride then
                (originalOverride :: any)(widget, setup)
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

        for key, value in properties do
            if type(value) == "function" and value == defaultProperties[key] then
                properties[key] = (value :: () -> any)()
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
        end
    ) :: (FrameArgs?, Children?) -> Frame,
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
        }
    ) :: (CanvasGroupArgs?, Children?) -> CanvasGroup,
    ImageLabel = createBasicObject(
        "imageLabel",
        {
            name = "ImageLabel",
            imageContent = Undefined,
            imageColor = Color3.new(1, 1, 1),
            imageRectOffset = Vector2.zero,
            imageRectSize = Vector2.zero,
            tileSize = function() return Units.Size(0, 0, 1, 1) end,
            imageTransparency = 0,
            resampleMode = Enum.ResamplerMode.Default,
            scaleType = Enum.ScaleType.Stretch,
            sliceCenter = Rect.new(0, 0, 0, 0),
            sliceScale = 1,
            isLoaded = false,
        },
        function()
            return Instance.new("ImageLabel")
        end,
        {
            imageContent = "ImageContent",
            imageColor = "ImageColor3",
            imageTransparency = "ImageTransparency",
            resampleMode = "ResampleMode",
            scaleType = "ScaleType",
            sliceCenter = "SliceCenter",
            sliceScale = "SliceScale",
            tileSize = "TileSize",
            imageRectOffset = "ImageRectOffset",
            imageRectSize = "ImageRectSize",
            isLoaded = "IsLoaded",
        },
        nil,
        { tileSize = "scaleToUDim2"},
        { isLoaded = true },
        { isLoaded = true }
    ) :: (ImageLabelArgs?, Children?) -> ImageLabel,
    ImageButton = createBasicObject(
        "imageButton",
        {
            name = "ImageButton",
            imageContent = Undefined,
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
            resampleMode = Enum.ResamplerMode.Default,
            scaleType = Enum.ScaleType.Stretch,
            sliceCenter = Rect.new(0, 0, 0, 0),
            sliceScale = 1,
            tileSize = function() return Units.Size(0, 0, 1, 1) end,
            imageRectOffset = Vector2.zero,
            imageRectSize = Vector2.zero,
            hoverImage = "",
            pressedImage = "",
            autoButtonColor = true,
            modal = false,
            selected = false,
            isLoaded = false,
            inputSink = Enum.InputSink.Activate,
            active = true,
            selectable = true
        },
        function()
            return Instance.new("ImageButton")
        end,
        {
            imageContent = "ImageContent",
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
            isLoaded = "IsLoaded",
        },
        {"Activated", "SecondaryActivated"},
        {
            tileSize = "scaleToUDim2"
        },
        { selected = true, isLoaded = true },
        { selected = true, isLoaded = true }
    ) :: (ImageButtonArgs?, Children?) -> ImageButton,
    ScrollingFrame = createBasicObject(
        "scrollingFrame",
        {
            name = "ScrollingFrame",
            canvasPosition = Vector2.zero,
            canvasSize = function() return Units.Size(0, 0, 1, 1) end,
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
        {
            canvasSize = "scaleToUDim2",
            canvasPosition = "scale"
        },
        {
            canvasPosition = "scale"
        }
    ) :: (ScrollingFrameArgs?, Children?) -> ScrollingFrame,
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
        {
            textSize = "scale",
        }
    ) :: (TextLabelArgs?, Children?) -> TextLabel,
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
            style = Enum.ButtonStyle.Custom,
            inputSink = Enum.InputSink.Activate,
            active = true,
            selectable = true
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
            textSize = "scale",
        }
    ) :: (TextButtonArgs?, Children?) -> TextButton,
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
            active = true,
            selectable = true
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
            textSize = "scale",
        },
        {
            cursorPosition = true,
            selectionStart = true
        }
    ) :: (TextBoxArgs?, Children?) -> TextBox,
    ViewportFrame = createBasicObject(
        "viewportFrame",
        {
            name = "ViewportFrame",
            imageColor = Color3.new(1, 1, 1),
            imageTransparency = 0,
            ambient = Color3.new(1, 1, 1),
            lightColor = Color3.new(1, 1, 1),
            lightDirection = Vector3.new(0, 1, -1),
            currentCamera = Undefined
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
    ) :: (ViewportFrameArgs?, Children?) -> ViewportFrame,
    VideoFrame = createBasicObject(
        "videoFrame",
        {
            name = "VideoFrame",
            video = Undefined,
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
        {"DidLoop", "Ended", "Loaded", "Paused", "Played"},
        nil,
        {
            playing = true,
            timePosition = true
        }
    ) :: (VideoFrameArgs?, Children?) -> VideoFrame,
}