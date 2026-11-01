--!strict
--[[
	BigNum
	Arbitrary-magnitude numbers stored as Mantissa * 10^Exponent.
	Invariant: 1 <= |Mantissa| < 10, or Mantissa == 0 (then Exponent == 0).
	Exponent is a plain Luau number, so values scale far past 1.79e308.

	Every function accepts a Value (BigNum | number | string) and never mutates its inputs.
	Metamethods (+ - * / ^ == < <= unary - tostring) are attached for convenience;
	strict-typed code should prefer the named functions.
]]

export type BigNum = { Mantissa: number, Exponent: number }
export type Value = BigNum | number | string

local BigNum = {}
local Meta: { [string]: any } = {}

-- Beyond this many orders of magnitude apart, the smaller operand cannot change the larger.
local PRECISION_DIGITS = 17
local MAX_DOUBLE_MANTISSA = 1.7976931348623157

local function make(mantissa: number, exponent: number): BigNum
	local value: BigNum = { Mantissa = mantissa, Exponent = exponent }
	setmetatable(value :: any, Meta)
	return value
end

local ZERO = make(0, 0)
local ONE = make(1, 0)

local function normalize(mantissa: number, exponent: number): BigNum
	if mantissa ~= mantissa or exponent ~= exponent then
		return ZERO
	end
	if mantissa == 0 then
		return ZERO
	end
	if mantissa == math.huge or mantissa == -math.huge then
		mantissa = if mantissa > 0 then MAX_DOUBLE_MANTISSA else -MAX_DOUBLE_MANTISSA
		exponent += 308
	end
	if exponent == math.huge or exponent == -math.huge then
		if exponent < 0 then
			return ZERO
		end
		return make(if mantissa > 0 then 1 else -1, math.huge)
	end
	-- Move any fractional exponent into the mantissa so Exponent stays integral.
	local whole = math.floor(exponent)
	if whole ~= exponent then
		mantissa *= 10 ^ (exponent - whole)
		exponent = whole
	end
	local sign = if mantissa < 0 then -1 else 1
	local magnitude = math.abs(mantissa)
	local shift = math.floor(math.log10(magnitude))
	if shift > 300 or shift < -300 then
		-- Split the division so 10^shift never overflows or underflows a double.
		local half = shift // 2
		magnitude = magnitude / 10 ^ half / 10 ^ (shift - half)
	else
		magnitude = magnitude / 10 ^ shift
	end
	-- Floating point drift guard.
	if magnitude >= 10 then
		magnitude /= 10
		shift += 1
	elseif magnitude < 1 then
		magnitude *= 10
		shift -= 1
	end
	return make(sign * magnitude, exponent + shift)
end

function BigNum.new(mantissa: number, exponent: number): BigNum
	return normalize(mantissa, exponent)
end

function BigNum.IsBigNum(value: any): boolean
	return type(value) == "table"
		and type(value.Mantissa) == "number"
		and type(value.Exponent) == "number"
end

function BigNum.FromNumber(n: number): BigNum
	return normalize(n, 0)
end

function BigNum.FromLog10(logValue: number): BigNum
	if logValue == -math.huge then
		return ZERO
	end
	local whole = math.floor(logValue)
	return normalize(10 ^ (logValue - whole), whole)
end

function BigNum.Deserialize(text: string): BigNum
	if text == "" then
		return ZERO
	end
	local mantissaText, exponentText = string.match(text, "^%s*([^|]+)|([^|]+)%s*$")
	if mantissaText and exponentText then
		return normalize(tonumber(mantissaText) or 0, tonumber(exponentText) or 0)
	end
	local plain = tonumber(text)
	if plain and plain == plain and plain ~= math.huge and plain ~= -math.huge then
		return normalize(plain, 0)
	end
	local sciMantissa, sciExponent = string.match(text, "^%s*([%+%-]?[%d%.]+)[eE]([%+%-]?[%d%.]+)%s*$")
	if sciMantissa and sciExponent then
		return normalize(tonumber(sciMantissa) or 0, tonumber(sciExponent) or 0)
	end
	-- "e1.5e20" style (exponent of exponent).
	local nested = string.match(text, "^%s*[eE](.+)$")
	if nested then
		local exponent = BigNum.ToNumber(BigNum.Deserialize(nested))
		return normalize(1, exponent)
	end
	warn("[BigNum] Could not parse value:", text)
	return ZERO
end

function BigNum.From(value: Value): BigNum
	if type(value) == "number" then
		return normalize(value, 0)
	elseif type(value) == "string" then
		return BigNum.Deserialize(value)
	end
	local big = value :: BigNum
	if getmetatable(big :: any) == Meta then
		return big
	end
	-- Tables that crossed the network lose their metatable; re-wrap them.
	return normalize(big.Mantissa, big.Exponent)
end

function BigNum.Zero(): BigNum
	return ZERO
end

function BigNum.One(): BigNum
	return ONE
end

function BigNum.Clone(value: Value): BigNum
	local a = BigNum.From(value)
	return make(a.Mantissa, a.Exponent)
end

function BigNum.IsZero(value: Value): boolean
	return BigNum.From(value).Mantissa == 0
end

function BigNum.Neg(value: Value): BigNum
	local a = BigNum.From(value)
	if a.Mantissa == 0 then
		return ZERO
	end
	return make(-a.Mantissa, a.Exponent)
end

function BigNum.Abs(value: Value): BigNum
	local a = BigNum.From(value)
	if a.Mantissa >= 0 then
		return a
	end
	return make(-a.Mantissa, a.Exponent)
end

function BigNum.Add(x: Value, y: Value): BigNum
	local a, b = BigNum.From(x), BigNum.From(y)
	if a.Mantissa == 0 then
		return b
	end
	if b.Mantissa == 0 then
		return a
	end
	local diff = a.Exponent - b.Exponent
	if diff > PRECISION_DIGITS then
		return a
	elseif diff < -PRECISION_DIGITS then
		return b
	elseif diff >= 0 then
		return normalize(a.Mantissa + b.Mantissa / 10 ^ diff, a.Exponent)
	else
		return normalize(b.Mantissa + a.Mantissa / 10 ^ -diff, b.Exponent)
	end
end

function BigNum.Sub(x: Value, y: Value): BigNum
	return BigNum.Add(x, BigNum.Neg(y))
end

function BigNum.Mul(x: Value, y: Value): BigNum
	local a, b = BigNum.From(x), BigNum.From(y)
	if a.Mantissa == 0 or b.Mantissa == 0 then
		return ZERO
	end
	return normalize(a.Mantissa * b.Mantissa, a.Exponent + b.Exponent)
end

function BigNum.Div(x: Value, y: Value): BigNum
	local a, b = BigNum.From(x), BigNum.From(y)
	if b.Mantissa == 0 then
		error("[BigNum] Division by zero", 2)
	end
	if a.Mantissa == 0 then
		return ZERO
	end
	return normalize(a.Mantissa / b.Mantissa, a.Exponent - b.Exponent)
end

-- Raises to a plain-number power. Negative bases keep their sign only for odd integer powers.
function BigNum.Pow(x: Value, power: number): BigNum
	local a = BigNum.From(x)
	if power == 0 then
		return ONE
	end
	if a.Mantissa == 0 then
		return ZERO
	end
	if power == 1 then
		return a
	end
	local negative = a.Mantissa < 0 and power % 2 == 1
	-- Split Exponent * power into whole and fractional parts to keep precision on huge exponents.
	local exponentProduct = a.Exponent * power
	local wholeProduct = math.floor(exponentProduct)
	local logRemainder = math.log10(math.abs(a.Mantissa)) * power + (exponentProduct - wholeProduct)
	local logWhole = math.floor(logRemainder)
	local result = normalize(10 ^ (logRemainder - logWhole), wholeProduct + logWhole)
	if negative then
		return BigNum.Neg(result)
	end
	return result
end

function BigNum.Sqrt(x: Value): BigNum
	return BigNum.Pow(BigNum.Abs(x), 0.5)
end

-- log10 of |x|; returns -math.huge for zero.
function BigNum.Log10(x: Value): number
	local a = BigNum.From(x)
	if a.Mantissa == 0 then
		return -math.huge
	end
	return math.log10(math.abs(a.Mantissa)) + a.Exponent
end

function BigNum.Cmp(x: Value, y: Value): number
	local a, b = BigNum.From(x), BigNum.From(y)
	local signA = if a.Mantissa > 0 then 1 elseif a.Mantissa < 0 then -1 else 0
	local signB = if b.Mantissa > 0 then 1 elseif b.Mantissa < 0 then -1 else 0
	if signA ~= signB then
		return if signA < signB then -1 else 1
	end
	if signA == 0 then
		return 0
	end
	if a.Exponent ~= b.Exponent then
		local result = if a.Exponent > b.Exponent then 1 else -1
		return result * signA
	end
	if a.Mantissa == b.Mantissa then
		return 0
	end
	return if a.Mantissa > b.Mantissa then 1 else -1
end

function BigNum.Eq(x: Value, y: Value): boolean
	return BigNum.Cmp(x, y) == 0
end

function BigNum.Lt(x: Value, y: Value): boolean
	return BigNum.Cmp(x, y) < 0
end

function BigNum.Le(x: Value, y: Value): boolean
	return BigNum.Cmp(x, y) <= 0
end

function BigNum.Gt(x: Value, y: Value): boolean
	return BigNum.Cmp(x, y) > 0
end

function BigNum.Ge(x: Value, y: Value): boolean
	return BigNum.Cmp(x, y) >= 0
end

function BigNum.Max(x: Value, y: Value): BigNum
	local a, b = BigNum.From(x), BigNum.From(y)
	return if BigNum.Cmp(a, b) >= 0 then a else b
end

function BigNum.Min(x: Value, y: Value): BigNum
	local a, b = BigNum.From(x), BigNum.From(y)
	return if BigNum.Cmp(a, b) <= 0 then a else b
end

function BigNum.Floor(x: Value): BigNum
	local a = BigNum.From(x)
	if a.Mantissa == 0 or a.Exponent >= PRECISION_DIGITS then
		return a
	end
	if a.Exponent < 0 then
		return if a.Mantissa > 0 then ZERO else normalize(-1, 0)
	end
	local raw = a.Mantissa * 10 ^ a.Exponent
	local floored = math.floor(raw)
	-- Values like 114.99999999 come from float noise on exact integers.
	if raw - floored > 0.9999999 then
		floored += 1
	end
	return normalize(floored, 0)
end

-- Converts to a double. Values past 1.79e308 become math.huge.
function BigNum.ToNumber(x: Value): number
	local a = BigNum.From(x)
	if a.Mantissa == 0 then
		return 0
	end
	if a.Exponent > 308 then
		return if a.Mantissa > 0 then math.huge else -math.huge
	end
	if a.Exponent < -323 then
		return 0
	end
	return a.Mantissa * 10 ^ a.Exponent
end

function BigNum.Serialize(x: Value): string
	local a = BigNum.From(x)
	if a.Mantissa == 0 then
		return "0|0"
	end
	return string.format("%.17g|%.17g", a.Mantissa, a.Exponent)
end

-- Suffix i covers 10^(3i). Built from short-scale Latin prefixes: K, M, B, T, Qd, Qn ... Ce (1e303).
local SUFFIXES: { string } = (function()
	local list = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No" }
	local units = { "", "U", "D", "T", "Qd", "Qn", "Sx", "Sp", "O", "N" }
	local tens = { "", "Dc", "Vg", "Tg", "Qdg", "Qng", "Sxg", "Spg", "Ocg", "Ng" }
	for illion = 10, 99 do
		table.insert(list, units[illion % 10 + 1] .. tens[illion // 10 + 1])
	end
	table.insert(list, "Ce")
	return list
end)()

local function trimNumber(value: number, decimals: number): string
	local text = string.format("%." .. decimals .. "f", value)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

local function formatExponent(exponent: number): string
	if exponent == math.huge then
		return "Infinity"
	end
	if math.abs(exponent) < 1e6 then
		return string.format("%d", exponent)
	end
	return BigNum.ToString(exponent)
end

function BigNum.ToString(x: Value, decimals: number?): string
	local a = BigNum.From(x)
	local places = decimals or 2
	if a.Mantissa == 0 then
		return "0"
	end
	if a.Exponent == math.huge then
		return if a.Mantissa > 0 then "Infinity" else "-Infinity"
	end
	local sign = if a.Mantissa < 0 then "-" else ""
	local mantissa = math.abs(a.Mantissa)
	local exponent = a.Exponent
	if exponent < 0 then
		local small = mantissa * 10 ^ exponent
		local text = trimNumber(small, places)
		if text == "0" then
			return sign .. trimNumber(mantissa, places) .. "e" .. formatExponent(exponent)
		end
		return sign .. text
	end
	if exponent < 3 then
		local plain = mantissa * 10 ^ exponent
		local rounded = math.floor(plain * 10 ^ places + 0.5) / 10 ^ places
		if rounded < 1000 then
			return sign .. trimNumber(rounded, places)
		end
		return sign .. "1" .. SUFFIXES[1]
	end
	local group = exponent // 3
	local scaled = mantissa * 10 ^ (exponent - group * 3)
	local rounded = math.floor(scaled * 10 ^ places + 0.5) / 10 ^ places
	if rounded >= 1000 then
		group += 1
		rounded = 1
	end
	if group <= #SUFFIXES then
		return sign .. trimNumber(rounded, places) .. SUFFIXES[group]
	end
	return sign .. trimNumber(mantissa, places) .. "e" .. formatExponent(exponent)
end

BigNum.Format = BigNum.ToString
BigNum.Suffixes = SUFFIXES

Meta.__index = BigNum
Meta.__add = function(a: Value, b: Value): BigNum
	return BigNum.Add(a, b)
end
Meta.__sub = function(a: Value, b: Value): BigNum
	return BigNum.Sub(a, b)
end
Meta.__mul = function(a: Value, b: Value): BigNum
	return BigNum.Mul(a, b)
end
Meta.__div = function(a: Value, b: Value): BigNum
	return BigNum.Div(a, b)
end
Meta.__pow = function(a: Value, b: number): BigNum
	return BigNum.Pow(a, b)
end
Meta.__unm = function(a: Value): BigNum
	return BigNum.Neg(a)
end
Meta.__eq = function(a: Value, b: Value): boolean
	return BigNum.Eq(a, b)
end
Meta.__lt = function(a: Value, b: Value): boolean
	return BigNum.Lt(a, b)
end
Meta.__le = function(a: Value, b: Value): boolean
	return BigNum.Le(a, b)
end
Meta.__tostring = function(a: Value): string
	return BigNum.ToString(a)
end

return BigNum
