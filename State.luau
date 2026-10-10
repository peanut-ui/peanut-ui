--!strict
--!optimize 2
const UserInputService = game:GetService("UserInputService")
const Utils = require(script.Parent.Types.Utils)
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

return State
