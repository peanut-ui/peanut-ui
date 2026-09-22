--!strict
const State = require(script.Parent.Parent.State)
const Widget = require(script.Parent.Parent.Types.Widget)
const Logging = require(script.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Components.Scaling")
local Scaling = {}

local function getScale(resolution: Vector2, reference: Vector2): number
    return math.min(
        resolution.X / reference.X,
        resolution.Y / reference.Y
    )
end

--- Applies responsive pixel scaling to a screen space.
---
--- The scale is calculated from the screen space's current size and the
--- reference resolution. The smaller scale factor between the width and
--- height is used, so the UI keeps its proportions and remains fully visible.
--- The scale is recalculated whenever the screen space changes size.
---
--- @param onScreenSpace The screen space whose UI should be scaled
--- @param referenceResolution The design resolution used as the scale baseline
--- @param floorScale Whether to round the scale down to an integer; useful for pixel-perfect UI where fractional scaling could place elements between pixels
--- @param minScale The smallest scale allowed after calculating the screen scale
--- @param maxScale The largest scale allowed after calculating the screen scale
---
--- ### Example
--- ```
--- Scaling.simpleScale(
---     space,
---     Vector2.new(844, 390),
---     true
--- )
--- ```
--- Here, `space` is the screen space to scale, `Vector2.new(844, 390)` is the
--- design resolution the UI is laid out for, and `true` enables integer scale
--- steps. This is a good default for pixel-oriented UI because it avoids half
--- pixels and keeps edges and text arranged cleanly. Use `false` or omit the
--- value when smoother fractional scaling is more important than pixel
--- alignment.
function Scaling.simpleScale(
    onScreenSpace: {
        read _isSpaceLike: true,
        read getObject: () -> ScreenGui,
        read changeScaleFn: (Widget.ScaleFn) -> ()
    },
    referenceResolution: Vector2,
    floorScale: boolean?,
    minScale: number?,
    maxScale: number?
)
    floorScale = floorScale == true

    local unwatchObjectCreation: () -> ()? = nil
    local objectConnection: RBXScriptConnection? = nil
    local object: GuiObject? = nil
    local createdByMe = false
    local scale = 1

    local function recalculateScale()
        if not object then
            scale = 1
            return
        end

        local size = object.AbsoluteSize
        scale = getScale(
            size,
            referenceResolution
        )

        if size.X <= 0 or size.Y <= 0 then
            scale = 1
            return
        end

        if floorScale == true then
            scale = math.max(
                minScale or 1, math.floor(scale)
            )
        end

        if minScale then
            scale = math.max(minScale, scale)
        end

        if maxScale then
            scale = math.min(scale, maxScale)
        end

        State.onScaleChanged()
    end

    local function connectObject()
        if not object or objectConnection then
            return
        end

        objectConnection = object
            :GetPropertyChangedSignal("AbsoluteSize")
            :Connect(function(...)
                recalculateScale()
            end)
    end

    if typeof(onScreenSpace) == "table" and onScreenSpace._isSpaceLike == true then
        local newObject = onScreenSpace.getObject()

        if newObject:IsA("ScreenGui") then
            object = Instance.new("Frame")
            object.Size = UDim2.new(1, 0, 1, 0)
            object.BackgroundTransparency = 1
            object.Interactable = false
            object.Active = false
            object.Name = "ScalingRoot"
            object.Parent = newObject
            createdByMe = true
        else
            logger.error("Object was not ScreenGui")
        end
        recalculateScale()
        connectObject()
    else
        logger.error("Unknown type!")
    end

    local scaleFn = {
        fn = function(px: number, getOriginal: boolean?)
            if getOriginal == true then
                return px / scale
            else
                return px * scale
            end
        end,
        stop = function()
            if unwatchObjectCreation then
                unwatchObjectCreation()
            end
            if objectConnection then
                objectConnection:Disconnect()
            end
            if createdByMe and object then
                object:Destroy()
            end
        end
    }

    onScreenSpace.changeScaleFn(scaleFn)
end

return Scaling