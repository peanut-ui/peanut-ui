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
    read getGuiObject: () -> GuiObject?,
    read listen: (property: string, (value: any) -> ...boolean?) -> (() -> ())
}
function Scaling.simpleScale(
    referenceObject: WidgetLike | GuiObject | any,
    referenceResolution: Vector2,
    roundScale: boolean?
)
    roundScale = if roundScale == nil then false else true

    local unwatchObjectCreation: () -> ()? = nil
    local objectConnection: RBXScriptConnection? = nil
    local object: GuiObject? = nil
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
        if not (referenceObject :: Instance):IsA("GuiObject") then
            logger.error("Reference object was Instance but not GuiObject!")
        end
        object = referenceObject :: GuiObject
        recalculateScale()
        connectObject()
    elseif typeof(referenceObject) == "table" and referenceObject.listen and referenceObject.getGuiObject then
        object = (referenceObject :: WidgetLike).getGuiObject()
        if not object then
            unwatchObjectCreation = (referenceObject :: WidgetLike).listen(
                "GuiObjectCreated",
                    function(obj)
                    object = obj
                    unwatchObjectCreation = nil
                    recalculateScale()
                    connectObject()
                    return true
                end
            )
        else
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
        end
    }
end

return Scaling