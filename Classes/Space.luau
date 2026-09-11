--!strict
--!optimize 2
const Players = game:GetService("Players")
const State = require(script.Parent.Parent.State)
const SpaceType = require(script.Parent.Parent.Types.Space)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Widget = require(script.Parent.Widget)

local logger = Logging.getLogger("PeanutUI.Classes.Space")

local registeredScreenSpaces: {[string]: SpaceType.ScreenSpace} = {}
local Space = {}

local function unsupported(...: never): never
    logger.error("Space does not support this function!")
    return nil :: never
end

-- Error on _setParent makes parent of widget that did addChild inconsistent
local function unsupportedInternal(...: never): never
    logger.critical("Space does not support this function! (internal function errored, state might be inconsistent)")
    return nil :: never
end

-- To ignore internal calls, like _createObject
local function unsupportedIgnore(...: never): never
    return nil :: never
end

local function linkProperties(
    widget: SpaceType.InternalInterface,
    properties: {[string]: string},
    transformFn: {[string]: (any) -> any}?
)
    local link = widget._linkProperty
    for name, property in properties do
        link(
            name :: any, property,
            transformFn and transformFn[property]
        )
    end
end

local function newSpace(
    name: string,
    registry: {[string]: any},
    createObjectFn: () -> LayerCollector,
    linkedProperties: {[string]: string},
    properties: {[string]: any}
): SpaceType.Interface
    if registry[name] then
        logger.error(`Cannot create name with existing name: {name}`)
    end

    local widget = Widget.new({
        properties = properties,
        defaultSetupOverride = function(widget: SpaceType.InternalInterface)
            widget._typeName = "space"
            widget._widgetLike = true
            widget._widgetName = name
            widget._spaceName = name

            widget.setTransition = unsupported
            widget.snapProperty = unsupported
            widget.setParent = unsupported
            widget.getParent = unsupported
            widget.createObject = unsupported
            widget._setParent = unsupportedInternal :: any
            widget._createObject = unsupportedIgnore :: any

            local newObject = createObjectFn()
            widget._setObject(newObject)

            local player = Players.LocalPlayer
            local existingPlayerGui = player:FindFirstChild("PlayerGui")
            if existingPlayerGui then
                newObject.Parent = player.PlayerGui
            else
                task.spawn(function()
                    -- 5 * 12 = 1 minute
                    for i = 1, 12 do
                        if not player or not player.Parent then
                            return
                        end
                        local playerGui = player:WaitForChild("PlayerGui", 5)
                        if not playerGui then
                            logger.warn("Getting PlayerGui timed out, trying again...")
                        else
                            newObject.Parent = playerGui
                            return
                        end
                    end

                    logger.critical("Could not get PlayerGui!")
                end)
            end

            local link = widget._linkProperty
            linkProperties(widget, linkedProperties)

            link("name", "Name")
            link("absoluteSize", "AbsoluteSize", nil, function(v)
                return State.scaleVector2(v, true)
            end, true)
            link("absolutePosition", "AbsolutePosition", nil, function(v)
                return State.scaleVector2(v, true)
            end, true)
            link("absoluteRotation" :: "absoluteRotation", "AbsoluteRotation", nil, nil, true)

            widget._redraw()
        end
    } :: any)  -- Idk why but linter says it's { [string]: any } and not args which is weird

    local widgetInternal = (widget :: any) :: SpaceType.InternalInterface
    widgetInternal._addCleanup(function()
        if registry[name] == widgetInternal then
            registry[name] = nil
        end
    end)

    registry[name] = widget

    return widgetInternal
end

local function createConstructor(
    registry: {[string]: any},
    createObjectFn: () -> LayerCollector,
    linkedProperties: {[string]: string},
    defaultProperties: {[string]: any}
): (string, {[string]: any}?) -> SpaceType.Interface
    return function(name, props)
        local properties = props and table.clone(props) or {}
        for key, value in defaultProperties do
            if properties[key] == nil then
                properties[key] = value
            end
        end

        return newSpace(
            name,
            registry,
            createObjectFn,
            linkedProperties,
            properties
        )
    end
end

local defaultScreenProperties: SpaceType.ScreenSpaceProps = {
    name = "ScreenSpace",
    absoluteSize = Vector2.zero,
    absolutePosition = Vector2.zero,
    absoluteRotation = 0,
    visible = true,
    displayOrder = 0,
    zIndexBehavior = Enum.ZIndexBehavior.Sibling,
    clipToDeviceSafeArea = true,
    ignoreGuiInset = false,
    safeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension,
    screenInsets = Enum.ScreenInsets.CoreUISafeInsets
}

table.freeze(defaultScreenProperties)

Space.createScreenSpace = createConstructor(
    registeredScreenSpaces,
    function(): LayerCollector
        return Instance.new("ScreenGui")
    end,
    {
        visible = "Enabled",
        displayOrder = "DisplayOrder",
        zIndexBehavior = "ZIndexBehavior",
        clipToDeviceSafeArea = "ClipToDeviceSafeArea",
        ignoreGuiInset = "IgnoreGuiInset",
        safeAreaCompatibility = "SafeAreaCompatibility",
        screenInsets = "ScreenInsets"
    },
    defaultScreenProperties
) :: (name: string, props: SpaceType.ScreenSpaceProps?) -> SpaceType.ScreenSpace

function Space.getScreenSpace(name: string): SpaceType.ScreenSpace
    if not registeredScreenSpaces[name] then
        logger.error(`Couldn't find space with name: {name}`)
    end

    return registeredScreenSpaces[name]
end

return Space