--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Curves = require(ReplicatedStorage.PeanutUI.Math.Curves)
const Oklab = require(ReplicatedStorage.PeanutUI.Math.Oklab)
const Tests = require(ReplicatedStorage.PeanutUI.Utils.Tests)

local function colorsAreNear(a: Color3, b: Color3): boolean
    return math.abs(a.R - b.R) < 0.0001
        and math.abs(a.G - b.G) < 0.0001
        and math.abs(a.B - b.B) < 0.0001
end

Tests.run("Curve endpoints", function()
    local endpointsAreValid = true
    for name, curve in (Curves :: any) do
        if name == "cubicBezier" then
            continue
        end

        if math.abs(curve(0)) > 0.001 or math.abs(curve(1) - 1) > 0.001 then
            endpointsAreValid = false
            break
        end
    end
    Tests.expectTrue("All easing curves start at zero and end at one", endpointsAreValid)
end)

Tests.run("Curve representative values", function()
    Tests.expectValue("Linear midpoint", Curves.Linear(0.5), 0.5)
    Tests.expectValue("Quadratic ease-in midpoint", Curves.EaseInQuad(0.5), 0.25)
    Tests.expectValue("Quadratic ease-out midpoint", Curves.EaseOutQuad(0.5), 0.75)
    Tests.expectValue("Quadratic ease-in-out midpoint", Curves.EaseInOutQuad(0.5), 0.5)
    Tests.expectValue("Ease-in-out cubic symmetry", Curves.EaseInOutCubic(0.25), 1 - Curves.EaseInOutCubic(0.75))
    Tests.expectValue("Ease-in-out bounce midpoint", Curves.EaseInOutBounce(0.5), 0.5)
    Tests.expectValue("Cubic bezier ease endpoint", Curves.Ease(1), 1)
    Tests.expectTrue("Cubic bezier easing is increasing", Curves.Ease(0.25) < Curves.Ease(0.75))
end)

Tests.run("Oklab and Oklch round trips", function()
    const colors = {
        Color3.new(0, 0, 0),
        Color3.new(1, 1, 1),
        Color3.new(1, 0, 0),
        Color3.new(0.2, 0.6, 0.9),
    }

    local roundTripsAreValid = true
    for _, color in colors do
        const labRoundTrip = Oklab.oklabToRgb(Oklab.rgbToOklab(color))
        const lchRoundTrip = Oklab.oklchToRgb(Oklab.rgbToOklch(color))
        if not colorsAreNear(color, labRoundTrip) or not colorsAreNear(color, lchRoundTrip) then
            roundTripsAreValid = false
            break
        end
    end
    Tests.expectTrue("RGB to Oklab/Oklch round trips preserve colors", roundTripsAreValid)

    const lab = { 0.7, 0.2, -0.1 }
    const lchRoundTrip = Oklab.oklchToOklab(Oklab.oklabToOklch(lab))
    Tests.expectTrue("Oklab and Oklch coordinate round trip", math.abs(lab[1] - lchRoundTrip[1]) < 0.000001
        and math.abs(lab[2] - lchRoundTrip[2]) < 0.000001
        and math.abs(lab[3] - lchRoundTrip[3]) < 0.000001)
end)

return {}