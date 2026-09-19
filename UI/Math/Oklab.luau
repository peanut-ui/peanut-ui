--!strict
--!native
-- Color conversions, for Spring and Ease engines

local function inverseGammaCorrect(c)
    return c <= 0.04045
        and c / 12.92
        or ((c + 0.055) / 1.055) ^ 2.4
end

local function gammaCorrect(c)
    return c <= 0.0031308
        and 12.92 * c
        or 1.055 * c ^ (1 / 2.4) - 0.055
end

local function rgbToOklab(value: Color3): {number}
    local r = inverseGammaCorrect(value.R)
    local g = inverseGammaCorrect(value.G)
    local b = inverseGammaCorrect(value.B)

    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    l = l >= 0 and l ^ (1 / 3) or -(-l) ^ (1 / 3)
    m = m >= 0 and m ^ (1 / 3) or -(-m) ^ (1 / 3)
    s = s >= 0 and s ^ (1 / 3) or -(-s) ^ (1 / 3)

    return {
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    }
end

local function oklabToRgb(value: {number}): Color3
    local l = value[1]
    local a = value[2]
    local b = value[3]

    local l_ = l + 0.3963377774 * a + 0.2158037573 * b
    local m_ = l - 0.1055613458 * a - 0.0638541728 * b
    local s_ = l - 0.0894841775 * a - 1.2914855480 * b

    l_ = l_ * l_ * l_
    m_ = m_ * m_ * m_
    s_ = s_ * s_ * s_

    local r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    local g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    local blue = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_

    r = math.clamp(gammaCorrect(r), 0, 1)
    g = math.clamp(gammaCorrect(g), 0, 1)
    blue = math.clamp(gammaCorrect(blue), 0, 1)

    return Color3.new(r, g, blue)
end

local function oklabToOklch(value: {number}): {number}
    local lightness = value[1]
    local a = value[2]
    local b = value[3]

    return {
        lightness,
        math.sqrt(a * a + b * b),
        math.atan2(b, a),
    }
end

local function oklchToOklab(value: {number}): {number}
    local lightness = value[1]
    local chroma = value[2]
    local hue = value[3]

    return {
        lightness,
        math.cos(hue) * chroma,
        math.sin(hue) * chroma,
    }
end

local function rgbToOklch(value: Color3): {number}
    return oklabToOklch(rgbToOklab(value))
end

local function oklchToRgb(value: {number}): Color3
    return oklabToRgb(oklchToOklab(value))
end

return {
    oklabToRgb = oklabToRgb,
    rgbToOklab = rgbToOklab,
    oklabToOklch = oklabToOklch,
    oklchToOklab = oklchToOklab,
    rgbToOklch = rgbToOklch,
    oklchToRgb = oklchToRgb,
}