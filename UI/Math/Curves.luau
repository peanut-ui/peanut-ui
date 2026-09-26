--!strict
--!native

local Curves = {}

local PI = math.pi
local HALF_PI = PI / 2

-- Linear

function Curves.Linear(t: number): number
	return t
end

-- Quadratic

function Curves.EaseInQuad(t: number): number
	return t * t
end

function Curves.EaseOutQuad(t: number): number
	return 1 - (1 - t) ^ 2
end

function Curves.EaseInOutQuad(t: number): number
	if t < 0.5 then
		return 2 * t * t
	end

	return 1 - (-2 * t + 2) ^ 2 / 2
end

-- Cubic

function Curves.EaseInCubic(t: number): number
	return t ^ 3
end

function Curves.EaseOutCubic(t: number): number
	return 1 - (1 - t) ^ 3
end

function Curves.EaseInOutCubic(t: number): number
	if t < 0.5 then
		return 4 * t ^ 3
	end

	return 1 - (-2 * t + 2) ^ 3 / 2
end

-- Quartic

function Curves.EaseInQuart(t: number): number
	return t ^ 4
end

function Curves.EaseOutQuart(t: number): number
	return 1 - (1 - t) ^ 4
end

function Curves.EaseInOutQuart(t: number): number
	if t < 0.5 then
		return 8 * t ^ 4
	end

	return 1 - (-2 * t + 2) ^ 4 / 2
end

-- Quintic

function Curves.EaseInQuint(t: number): number
	return t ^ 5
end

function Curves.EaseOutQuint(t: number): number
	return 1 - (1 - t) ^ 5
end

function Curves.QuintInOut(t: number): number
	if t < 0.5 then
		return 16 * t ^ 5
	end

	return 1 - (-2 * t + 2) ^ 5 / 2
end

-- Sine

function Curves.EaseInSine(t: number): number
	return 1 - math.cos(t * HALF_PI)
end

function Curves.SineOut(t: number): number
	return math.sin(t * HALF_PI)
end

function Curves.SineInOut(t: number): number
	return -(math.cos(PI * t) - 1) / 2
end

-- Exponential

function Curves.EaseInExpo(t: number): number
	if t == 0 then
		return 0
	end

	return 2 ^ (10 * t - 10)
end

function Curves.EaseOutExpo(t: number): number
	if t == 1 then
		return 1
	end

	return 1 - 2 ^ (-10 * t)
end

function Curves.EaseInOutExpo(t: number): number
	if t == 0 or t == 1 then
		return t
	end

	if t < 0.5 then
		return 2 ^ (20 * t - 10) / 2
	end

	return (2 - 2 ^ (-20 * t + 10)) / 2
end

-- Circular

function Curves.EaseInCirc(t: number): number
	return 1 - math.sqrt(1 - t * t)
end

function Curves.EaseOutCirc(t: number): number
	return math.sqrt(1 - (t - 1) ^ 2)
end

function Curves.EaseInOutCirc(t: number): number
	if t < 0.5 then
		return (1 - math.sqrt(1 - (2 * t) ^ 2)) / 2
	end

	return (math.sqrt(1 - (-2 * t + 2) ^ 2) + 1) / 2
end

-- Back

local BACK = 1.70158
local BACK_IN = BACK + 1
local BACK_IN_OUT = BACK * 1.525

function Curves.EaseInBack(t: number): number
	return BACK_IN * t ^ 3 - BACK * t ^ 2
end

function Curves.EaseOutBack(t: number): number
	local x = t - 1

	return 1 + BACK_IN * x ^ 3 + BACK * x ^ 2
end

function Curves.EaseInOutBack(t: number): number
	if t < 0.5 then
		local x = 2 * t

		return (x ^ 2 * ((BACK_IN_OUT + 1) * x - BACK_IN_OUT)) / 2
	end

	local x = 2 * t - 2

	return (
		x ^ 2 * ((BACK_IN_OUT + 1) * x + BACK_IN_OUT) + 2
	) / 2
end

-- Elastic

function Curves.EaseInElastic(t: number): number
	if t == 0 or t == 1 then
		return t
	end

	return -2 ^ (10 * t - 10)
		* math.sin((t * 10 - 10.75) * (2 * PI / 3))
end

function Curves.EaseOutElastic(t: number): number
	if t == 0 or t == 1 then
		return t
	end

	return 2 ^ (-10 * t)
		* math.sin((t * 10 - 0.75) * (2 * PI / 3))
		+ 1
end

function Curves.EaseInOutElastic(t: number): number
	if t == 0 or t == 1 then
		return t
	end

	if t < 0.5 then
		return -(
			2 ^ (20 * t - 10)
			* math.sin((20 * t - 11.125) * (2 * PI / 4.5))
		) / 2
	end

	return (
		2 ^ (-20 * t + 10)
		* math.sin((20 * t - 11.125) * (2 * PI / 4.5))
	) / 2 + 1
end

-- Bounce

local BOUNCE_N1 = 7.5625
local BOUNCE_D1 = 2.75

function Curves.EaseOutBounce(t: number): number
	if t < 1 / BOUNCE_D1 then
		return BOUNCE_N1 * t * t
	elseif t < 2 / BOUNCE_D1 then
		t -= 1.5 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.75
	elseif t < 2.5 / BOUNCE_D1 then
		t -= 2.25 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.9375
	else
		t -= 2.625 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.984375
	end
end

function Curves.EaseInBounce(t: number): number
	return 1 - Curves.EaseOutBounce(1 - t)
end

function Curves.EaseInOutBounce(t: number): number
	if t < 0.5 then
		return (1 - Curves.EaseOutBounce(1 - 2 * t)) / 2
	end

	return (1 + Curves.EaseOutBounce(2 * t - 1)) / 2
end

-- Ease and cubic bezier

local function cubicBezier(
	x1: number,
	y1: number,
	x2: number,
	y2: number
): (number) -> number
	return function(x: number): number
		if x == 0 or x == 1 then
			return x
		end

		local function sampleX(t: number): number
			local omt = 1 - t
			return 3 * omt * omt * t * x1
				+ 3 * omt * t * t * x2
				+ t * t * t
		end

		local function sampleY(t: number): number
			local omt = 1 - t
			return 3 * omt * omt * t * y1
				+ 3 * omt * t * t * y2
				+ t * t * t
		end

		local low = 0
		local high = 1

		for _ = 1, 12 do
			local middle = (low + high) / 2

			if sampleX(middle) < x then
				low = middle
			else
				high = middle
			end
		end

		return sampleY((low + high) / 2)
	end
end

Curves.Ease = cubicBezier(0.25, 0.1, 0.25, 1)
Curves.EaseIn = cubicBezier(0.42, 0, 1, 1)
Curves.EaseOut = cubicBezier(0, 0, 0.58, 1)
Curves.EaseInOut = cubicBezier(0.42, 0, 0.58, 1)

Curves.cubicBezier = cubicBezier

return table.freeze(Curves)