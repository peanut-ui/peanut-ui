--!strict
const State = require(script.Parent.Parent.State)
const Logging = require(script.Parent.Parent.Utils.Logging)

local logger = Logging.getLogger("PeanutUI.Classes.Scaling")
local Scaling = {}

local function getScale(resolution: Vector2, reference: Vector2): number
    return math.min(
        resolution.X / reference.X,
        resolution.Y / reference.Y
    )
end

type WidgetLike = {
    [string]: any,
    read getGuiObject: () -> Instance?,
    read listen: (property: string, (value: any) -> ...boolean?) -> (() -> ())
}
function Scaling.simpleScale(
    referenceObject: WidgetLike | GuiObject | ScreenGui | any,
    referenceResolution: Vector2,
    roundScale: boolean?
)
    roundScale = if roundScale == nil then false else true

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

        scale = getScale(
            object.AbsoluteSize,
            referenceResolution
        )
        print(scale, object.AbsoluteSize.X, object.AbsoluteSize.Y)
        if roundScale == true then
            scale = math.max(
                1, math.round(scale)
            )
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

    if typeof(referenceObject) == "Instance" then
        if (referenceObject :: Instance):IsA("ScreenGui") then
            object = Instance.new("Frame")
            object.Size = UDim2.new(1, 0, 1, 0)
            object.BackgroundTransparency = 1
            object.Interactable = false
            object.Active = false
            object.Name = "ScalingRoot"
            object.Parent = referenceObject
            createdByMe = true
        elseif (referenceObject :: Instance):IsA("GuiObject") then
            object = referenceObject :: GuiObject
            recalculateScale()
            connectObject()
        else
            logger.error("Reference object was Instance but not GuiObject or ScreenGui!")
        end
    elseif typeof(referenceObject) == "table" and referenceObject.listen and referenceObject.getGuiObject then
        local newObject = (referenceObject :: WidgetLike).getGuiObject()
        if not newObject then
            unwatchObjectCreation = (referenceObject :: WidgetLike).listen(
                "GuiObjectCreated",
                function(obj: Instance)
                    if not obj:IsA("GuiObject") then
                        logger.error("Created object was not a GuiObject!")
                        error("")
                    end
                    object = obj
                    unwatchObjectCreation = nil
                    recalculateScale()
                    connectObject()
                    return true
                end
            )
        else
            if newObject:IsA("ScreenGui") then
                object = Instance.new("Frame")
                object.Size = UDim2.new(1, 0, 1, 0)
                object.BackgroundTransparency = 1
                object.Interactable = false
                object.Active = false
                object.Name = "ScalingRoot"
                object.Parent = newObject
                createdByMe = true
            elseif newObject:IsA("GuiObject") then
                object = newObject
            else
                logger.error("Object was not ScreenGui or GuiObject")
            end
            recalculateScale()
            connectObject()
        end
    else
        logger.error("Reference object has unknown type!")
    end

    return {
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
end

return Scaling