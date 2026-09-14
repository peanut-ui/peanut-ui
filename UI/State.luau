--!strict
--!optimize 2
const Utils = require(script.Parent.Types.Utils)
const Widget = require(script.Parent.Types.Widget)
const Logging = require(script.Parent.Utils.Logging)
const Signals = require(script.Parent.Utils.Signals)
const Units = require(script.Parent.Utils.Units)

local uiVersion = {
    major = 0,
    minor = 1,
    patch = 0,
    label = "beta"
}

local function buildVersion()
    local v = `{uiVersion.major}.{uiVersion.minor}.{uiVersion.patch}`
    if #uiVersion.label > 0 then
        v ..= `-{uiVersion.label}`
    end

    return v
end

const logger = Logging.getLogger("PeanutUI.State")

local State = {}

State.Version = uiVersion
State.VersionString = buildVersion()

State.signals = Signals.new()

local registeredWidgets: {[number]: Widget.Interface} = {}

local scaleFunction = function(px: number, getOriginal: boolean?)
    return px
end
local stopScale: () -> ()? = nil

setmetatable(registeredWidgets, { __mode = "v" })

function State.addWidget(widget: Widget.Interface)
    registeredWidgets[widget._uniqueId] = widget
end

function State.removeWidget(widget: Widget.Interface | number)
    if typeof(widget) == "number" then
        local registeredWidget = registeredWidgets[widget]

        if not registeredWidget then
            return
        end

        registeredWidgets[widget] = nil
        registeredWidget.destroy()
    elseif typeof(widget) == "table" and widget._uniqueId then
        registeredWidgets[widget._uniqueId] = nil
        widget.destroy()
    else
        logger.warn("Unknown type of widget")
    end
end

function State.scaleVector2(obj: Vector2, getOriginal: boolean?): Vector2
    return Vector2.new(
        scaleFunction(obj.X, getOriginal),
        scaleFunction(obj.Y, getOriginal)
    )
end

function State.scaleUDim2(obj: UDim2, getOriginal: boolean?): UDim2
    return UDim2.new(
        obj.X.Scale,
        scaleFunction(obj.X.Offset, getOriginal),
        obj.Y.Scale,
        scaleFunction(obj.Y.Offset, getOriginal)
    )
end

function State.scaleUDim(obj: UDim, getOriginal: boolean?): UDim
    return UDim.new(
        obj.Scale,
        scaleFunction(obj.Offset, getOriginal)
    )
end

function State.scaleSize(size: Utils.Size, getOriginal: boolean?): Utils.Size
    return Units.Size(
        scaleFunction(size.width, getOriginal),
        scaleFunction(size.height, getOriginal),
        size.widthScale,
        size.heightScale
    )
end

function State.scalePosition(pos: Utils.Position, getOriginal: boolean?): Utils.Position
    return Units.Position(
        scaleFunction(pos.x, getOriginal),
        scaleFunction(pos.y, getOriginal),
        pos.xScale,
        pos.yScale
    )
end

function State.scaleUnit(unit: Utils.Unit, getOriginal: boolean?): Utils.Unit
    return Units.Unit(
        scaleFunction(unit.px, getOriginal),
        unit.scale
    )
end

function State.scalePx(px: number, getOriginal: boolean?): number
    return scaleFunction(px, getOriginal)
end

type ScaleFn = (px: number, getOriginal: boolean?) -> number
function State.setScaleFunction(
    fn: ScaleFn | {
        fn: ScaleFn,
        stop: () -> ()
    }
)
    if stopScale then
        stopScale()
        stopScale = nil
    end

    if typeof(fn) == "function" then
        scaleFunction = fn
    elseif typeof(fn) == "table" then
        scaleFunction = fn.fn
        stopScale = fn.stop
    else
        logger.error("Type for scale function was not table or number!")
    end
end

function State.onScaleChanged()
    -- TODO: Update only properties that depend on scale
    State.redrawAll()
end

function State.redrawAll()
    for _, widget in registeredWidgets do
        (widget :: Widget.InternalInterface)._redraw()
    end
end

return State
