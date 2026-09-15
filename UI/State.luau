--!strict
--!optimize 2
const UserInputService = game:GetService("UserInputService")
const Utils = require(script.Parent.Types.Utils)
const Widget = require(script.Parent.Types.Widget)
const Logging = require(script.Parent.Utils.Logging)
const Ref = require(script.Parent.Utils.Ref)
const Signals = require(script.Parent.Utils.Signals)

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

local input = Ref.new("unknown") :: Utils.Ref<"gamepad" | "desktop" | "touch">

do
    local inputMap = {
        [Enum.PreferredInput.Gamepad] = "gamepad",
        [Enum.PreferredInput.KeyboardAndMouse] = "desktop",
        [Enum.PreferredInput.MicroGamepad] = "gamepad",
        [Enum.PreferredInput.Touch] = "touch",
    }

    local function updateInputType()
        input.setValue(inputMap[UserInputService.PreferredInput])
    end

    UserInputService
        :GetPropertyChangedSignal("PreferredInput")
        :Connect(updateInputType)

    updateInputType()
end

State.Version = uiVersion
State.VersionString = buildVersion()

State.preferredInput = input
State.signals = Signals.new()

local registeredWidgets: {[number]: Widget.BaseInterface} = {}

setmetatable(registeredWidgets, { __mode = "v" })

function State.addWidget(widget: Widget.BaseInterface | any)
    registeredWidgets[widget._uniqueId] = widget
end

function State.removeWidget(widget: Widget.BaseInterface | number)
    if typeof(widget) == "number" then
        local registeredWidget = registeredWidgets[widget]

        if not registeredWidget then
            return
        end

        registeredWidgets[widget] = nil
        if registeredWidget.isImplemented "destroy" then
            registeredWidget.destroy()
        end
    elseif typeof(widget) == "table" and widget._uniqueId then
        registeredWidgets[widget._uniqueId] = nil
        if widget.isImplemented "destroy" then
            widget.destroy()
        end
    else
        logger.warn("Unknown type of widget")
    end
end

function State.onScaleChanged()
    -- TODO: Update only properties that depend on scale
    State.redrawAll()
end

function State.redrawAll()
    for _, widget in registeredWidgets do
        -- Widget may not implement redraw
        if widget.isImplemented "_redraw" then
            (widget :: Widget.InternalInterface)._redraw()
        end
    end
end

return State
