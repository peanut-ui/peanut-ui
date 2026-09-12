--!strict
--!optimize 2

const Component = require(script.Parent.Classes.Component)
const Space = require(script.Parent.Classes.Space)
const Widgets = require(script.Parent.Components.Widgets)
const Spring = require(script.Parent.Parent.Shared.Spring)
const State = require(script.Parent.State)
const Animations = require(script.Parent.Types.Animations)
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

local function createTestTransition(): Animations.Transition
    local transition = {}
    transition._typeName = "transition" :: "transition"

    function transition.animate(obj: Instance, property: string, to: any)
        print("Animating", obj, property)
        Spring.target(obj, 0.4, 4, { [property] = to })
    end

    function transition.stop(obj: Instance, property: string)
        Spring.stop(obj, property)
    end

    function transition.isRunning(obj: Instance, property: string): boolean
        return Spring.isAnimating(obj, property)
    end

    function transition.stopAll(obj: Instance)
        Spring.stop(obj)
    end

    return table.freeze(transition)
end

-- local scale = 5
-- State.setScaleFunction(function(px: number, getOriginal: boolean?)
--     if getOriginal then
--         return px / scale
--     else
--         return px * scale
--     end
-- end)

local Counter = Component.defineComponent(function(props)
    local clickCount = Ref.new(0)
    local size = Ref.reactive(Units.Size(150, 150))
    local fontSize = Ref.new(14)

    local color = Ref.autoComputed(function(use): Color3
        local index = ((use(clickCount) - 1) % #backgroundColors) + 1
        return backgroundColors[index]
    end)

    return Widgets.Frame {
        properties = {
            anchorPoint = Vector2.new(0.5, 0.5),
            position = Units.Position(nil, nil, 0.5, 0.5),
            size = size,
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
                    size = Units.Size(nil, nil, 1, 0.75),
                    textSize = fontSize
                }
            },
            Widgets.TextButton {
                properties = {
                    text = "Click me!",
                    backgroundColor = Color3.fromRGB(73, 66, 66),
                    textColor = Color3.fromRGB(236, 236, 236),
                    size = Units.Size(nil, nil, 1, 0.25),
                    position = Units.Position(0, 0, 0, 0.75),
                },
                events = {
                    Activated = function()
                        clickCount.increaseValue(1)
                        size.width += 25
                        size.height += 25
                        fontSize.increaseValue(2)
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
        },
        transitions = {
            size = createTestTransition(),
            backgroundColor = createTestTransition()
        }
    }
end)

local counter = Counter()
-- counter.setParent(space)
counter.setParent(Space.getScreenSpace("Main"))

return {}