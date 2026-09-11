--!strict
--!optimize 2

const Component = require(script.Parent.Classes.Component)
const Space = require(script.Parent.Classes.Space)
const Widgets = require(script.Parent.Components.Widgets)
const State = require(script.Parent.State)
const Widget = require(script.Parent.Types.Widget)
const Logging = require(script.Parent.Utils.Logging)
const Ref = require(script.Parent.Utils.Ref)
const Units = require(script.Parent.Utils.Units)

Logging.setLevel(1)
local space = Space.createScreenSpace("Main")

local backgroundColors = {
    Color3.fromHex("cafeed"),
    Color3.fromHex("#fecaca"),
    Color3.fromHex("#cad1fe"),
    Color3.fromHex("#ff69d7"),
    Color3.fromHex("#697dff"),
}

local scale = 3
State.setScaleFunction(function(px: number, getOriginal: boolean?)
    if getOriginal then
        return px / scale
    else
        return px * scale
    end
end)

local Counter = Component.defineComponent(function(props)
    local clickCount = Ref.new(0)

    local color = Ref.autoComputed(function(use): Color3
        local index = ((use(clickCount) - 1) % #backgroundColors) + 1
        return backgroundColors[index]
    end)

    return Widgets.Frame {
        properties = {
            anchorPoint = Vector2.new(0.5, 0.5),
            position = Units.Position(nil, nil, 0.5, 0.5),
            size = Units.Size(150, 150),
            backgroundColor = color
        },
        children = {
            Widgets.TextLabel {
                properties = {
                    text = Ref.transform(clickCount, function(value)
                        return `Click count: {value}`
                    end),
                    backgroundTransparency = 1,
                    textColor = Color3.new(0, 0, 0),
                    size = Units.Size(nil, nil, 1, 0.75)
                }
            },
            Widgets.TextButton {
                properties = {
                    text = "Click me!",
                    backgroundColor = Color3.fromRGB(73, 66, 66),
                    textColor = Color3.fromRGB(236, 236, 236),
                    size = Units.Size(nil, nil, 1, 0.25),
                    position = Units.Position(0, 0, 0, 0.75)
                },
                events = {
                    Activated = function()
                        clickCount.increaseValue(1)
                        scale /= 2
                        State.redrawAll()
                    end
                },
                modifiers = {
                    cornerRadius = { px = 8 }
                }
            }
        },
        modifiers = {
            cornerRadius = { px = 24 },
            padding = { px = 16 }
        }
    }
end)

local counter = Counter()
-- counter.setParent(space)
counter.setParent(Space.getScreenSpace("Main"))

return {}