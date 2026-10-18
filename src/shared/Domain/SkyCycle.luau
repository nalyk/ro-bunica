--!strict
-- Ciclul de lumină al satului: cadre-cheie pe oră (ClockTime) și interpolarea lor. Pur și testat; clientul
-- (LightingDirector) aplică rezultatul pe Lighting, Atmosphere și efectele de post-procesare.

local SkyCycle = {}

export type Look = {
	ambient: Color3,
	outdoor: Color3,
	colorTop: Color3, -- ColorShift_Top: lumina soarelui pe fețele de sus
	colorBottom: Color3,
	brightness: number,
	fogColor: Color3, -- Atmosphere.Color
	decay: Color3, -- Atmosphere.Decay (culoarea orizontului departe)
	haze: number,
	density: number,
	tint: Color3, -- ColorCorrection.TintColor
	saturation: number,
	contrast: number,
	bloom: number,
	sunRays: number,
}

local RGB = Color3.fromRGB

local NIGHT: Look = {
	ambient = RGB(80, 88, 142),
	outdoor = RGB(95, 106, 168),
	colorTop = RGB(155, 175, 255),
	colorBottom = RGB(45, 46, 88),
	brightness = 1.35,
	fogColor = RGB(60, 70, 120),
	decay = RGB(40, 45, 95),
	haze = 1.4,
	density = 0.32,
	tint = RGB(205, 215, 255),
	saturation = 0.05,
	contrast = 0.1,
	bloom = 0.55,
	sunRays = 0.02,
}

-- Ore (0–24) și aspectul lor. Paleta: caldă și saturată ziua, albastru-violet noaptea (citibil, nu negru).
SkyCycle.KEYS = {
	{
		hour = 0,
		look = NIGHT,
	},
	{
		-- noaptea ține până la 4:30; zorii vin doar între 4:30 și 5:36
		hour = 4.5,
		look = NIGHT,
	},
	{
		hour = 5.6,
		look = {
			ambient = RGB(120, 95, 120),
			outdoor = RGB(170, 130, 150),
			colorTop = RGB(255, 170, 170),
			colorBottom = RGB(80, 60, 90),
			brightness = 1.6,
			fogColor = RGB(230, 170, 180),
			decay = RGB(200, 130, 150),
			haze = 1.8,
			density = 0.34,
			tint = RGB(255, 235, 240),
			saturation = 0.12,
			contrast = 0.06,
			bloom = 0.6,
			sunRays = 0.12,
		},
	},
	{
		hour = 9,
		look = {
			ambient = RGB(125, 120, 110),
			outdoor = RGB(165, 160, 145),
			colorTop = RGB(255, 245, 220),
			colorBottom = RGB(90, 85, 80),
			brightness = 2.4,
			fogColor = RGB(200, 220, 240),
			decay = RGB(150, 185, 220),
			haze = 1.0,
			density = 0.26,
			tint = RGB(255, 252, 245),
			saturation = 0.18,
			contrast = 0.06,
			bloom = 0.35,
			sunRays = 0.06,
		},
	},
	{
		hour = 14,
		look = {
			ambient = RGB(130, 122, 108),
			outdoor = RGB(170, 160, 140),
			colorTop = RGB(255, 240, 210),
			colorBottom = RGB(95, 85, 75),
			brightness = 2.7,
			fogColor = RGB(205, 222, 240),
			decay = RGB(160, 190, 225),
			haze = 0.9,
			density = 0.25,
			tint = RGB(255, 250, 240),
			saturation = 0.2,
			contrast = 0.07,
			bloom = 0.3,
			sunRays = 0.05,
		},
	},
	{
		hour = 17.4,
		look = {
			ambient = RGB(140, 110, 85),
			outdoor = RGB(190, 145, 105),
			colorTop = RGB(255, 200, 130),
			colorBottom = RGB(100, 70, 60),
			brightness = 2.3,
			fogColor = RGB(250, 200, 150),
			decay = RGB(240, 150, 110),
			haze = 1.6,
			density = 0.3,
			tint = RGB(255, 236, 215),
			saturation = 0.24,
			contrast = 0.08,
			bloom = 0.5,
			sunRays = 0.16,
		},
	},
	{
		hour = 18.6,
		look = {
			ambient = RGB(135, 112, 120),
			outdoor = RGB(180, 145, 140),
			colorTop = RGB(255, 190, 145),
			colorBottom = RGB(90, 70, 85),
			brightness = 2.0,
			fogColor = RGB(235, 175, 155),
			decay = RGB(185, 125, 150),
			haze = 1.6,
			density = 0.34,
			tint = RGB(255, 225, 220),
			saturation = 0.22,
			contrast = 0.1,
			bloom = 0.65,
			sunRays = 0.2,
		},
	},
	{
		hour = 20,
		look = {
			ambient = RGB(95, 95, 150),
			outdoor = RGB(110, 112, 178),
			colorTop = RGB(170, 165, 255),
			colorBottom = RGB(50, 48, 95),
			brightness = 1.5,
			fogColor = RGB(90, 90, 160),
			decay = RGB(70, 60, 130),
			haze = 1.6,
			density = 0.32,
			tint = RGB(220, 220, 255),
			saturation = 0.1,
			contrast = 0.1,
			bloom = 0.55,
			sunRays = 0.04,
		},
	},
}

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

function SkyCycle.blend(a: Look, b: Look, t: number): Look
	local out: { [string]: any } = {}
	for key, value in a :: any do
		local other = (b :: any)[key]
		if typeof(value) == "Color3" then
			out[key] = (value :: Color3):Lerp(other, t)
		else
			out[key] = lerpNumber(value :: number, other :: number, t)
		end
	end
	return out :: any
end

-- Aspectul la ora `hour` (0–24), cu trecere netedă între cadrele-cheie (și peste miezul nopții)
function SkyCycle.at(hour: number): Look
	local keys = SkyCycle.KEYS
	local h = hour % 24
	for index, key in keys do
		local nextKey = keys[index + 1] or { hour = keys[1].hour + 24, look = keys[1].look }
		if h >= key.hour and h < nextKey.hour then
			local t = (h - key.hour) / (nextKey.hour - key.hour)
			return SkyCycle.blend(key.look, nextKey.look, smooth(t))
		end
	end
	return keys[1].look
end

-- Ora din fază: ziua trece de la 7 la 18,8 (apus); noaptea de la 18,8 la 6,5, cu zorii doar la final
function SkyCycle.hourFor(phase: string, progress: number): number
	local p = math.clamp(progress, 0, 1)
	if phase == "Night" then
		return (18.8 + p * 11.7) % 24
	end
	return 7 + p * 11.8
end

return SkyCycle
