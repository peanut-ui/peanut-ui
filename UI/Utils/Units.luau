--!strict
--!optimize 2
const Utils = require(script.Parent.Parent.Types.Utils)

-- Reactive replacements for UDim2 and UDim

local Units = {}

local function size(
    width: number?,
    height: number?,
    widthScale: number?,
    heightScale: number?
): Utils.Size
    return {
        _typeName = "size",
        height = height or 0,
        width = width or 0,
        heightScale = heightScale or 0,
        widthScale = widthScale or 0,
    }
end

local function position(
    x: number?,
    y: number?,
    xScale: number?,
    yScale: number?
): Utils.Position
    return {
        _typeName = "position",
        x = x or 0,
        y = y or 0,
        xScale = xScale or 0,
        yScale = yScale or 0,
    }
end

local function unit(
    px: number?,
    scale: number?
): Utils.Unit
    return {
        _typeName = "unit",
        px = px or 0,
        scale = scale or 0
    }
end

Units.Position = position
Units.Size = size
Units.Unit = unit

function Units.SizeFromUDim2(obj: UDim2): Utils.Size
    return size(
        obj.Width.Offset,
        obj.Height.Offset,
        obj.Width.Scale,
        obj.Height.Scale
    )
end

function Units.PositionFromUDim2(obj: UDim2): Utils.Position
    return position(
        obj.X.Offset,
        obj.Y.Offset,
        obj.X.Scale,
        obj.Y.Scale
    )
end

function Units.UnitFromUDim(obj: UDim): Utils.Unit
    return unit(
        obj.Offset,
        obj.Scale
    )
end

function Units.ToUDim2(obj: Utils.Size | Utils.Position | UDim2): UDim2
    if typeof(obj) == "UDim2" then
        return obj
    end

    if type(obj) == "table" then
        if obj._typeName == "size" then
            return UDim2.new(
                obj.widthScale,
                obj.width,
                obj.heightScale,
                obj.height
            )
        elseif obj._typeName == "position" then
            return UDim2.new(
                obj.xScale,
                obj.x,
                obj.yScale,
                obj.y
            )
        end
    end
    error("Unknown type", 2)
end

function Units.ToUDim(obj: Utils.Unit | UDim): UDim
    if typeof(obj) == "UDim" then
        return obj
    end

    if type(obj) == "table" then
        if obj._typeName == "unit" then
            return UDim.new(
                obj.px,
                obj.scale
            )
        end
    end
    error("Unknown type", 2)
end

return Units