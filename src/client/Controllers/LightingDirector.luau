--!strict
-- Directorul de lumină: soarele trece continuu peste sat (zori, amiază, oră de aur, apus, oră albastră,
-- noapte cu lună), sincron cu faza jocului. Atmosfera, corecția de culoare, bloom-ul și razele soarelui
-- urmează cadrele-cheie din SkyCycle; vremea nuanțează peste. Totul e local (Lighting pe client).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayNight = require(Shared.Config.DayNight)
local GameState = require(Shared.GameState)
local SkyCycle = require(Shared.Domain.SkyCycle)

local LightingDirector = {}

-- Nuanțe de vreme peste ciclul zilei: (culoare de amestec, cât de mult, saturație în plus, luminozitate ×)
local WEATHER_TINT: { [string]: { color: Color3, amount: number, saturation: number, brightness: number } } =
	{
		Rain = { color = Color3.fromRGB(120, 140, 170), amount = 0.45, saturation = -0.15, brightness = 0.7 },
		Hail = { color = Color3.fromRGB(170, 190, 220), amount = 0.4, saturation = -0.1, brightness = 0.8 },
		FrostNight = {
			color = Color3.fromRGB(170, 210, 255),
			amount = 0.35,
			saturation = -0.05,
			brightness = 0.95,
		},
		GoldHarvest = {
			color = Color3.fromRGB(255, 205, 90),
			amount = 0.35,
			saturation = 0.12,
			brightness = 1.1,
		},
		Rainbow = { color = Color3.fromRGB(255, 170, 230), amount = 0.2, saturation = 0.3, brightness = 1.1 },
		BunicaAngry = {
			color = Color3.fromRGB(255, 90, 70),
			amount = 0.45,
			saturation = 0.1,
			brightness = 0.9,
		},
	}

-- Norii (Clouds) și vântul (GlobalWind, mișcă iarba terenului și particulele) după vreme
local SKY_WEATHER: { [string]: { cover: number, density: number, color: Color3, wind: Vector3 } } = {
	Rain = {
		cover = 0.88,
		density = 0.75,
		color = Color3.fromRGB(150, 155, 165),
		wind = Vector3.new(16, 0, 7),
	},
	Hail = {
		cover = 0.92,
		density = 0.8,
		color = Color3.fromRGB(165, 172, 185),
		wind = Vector3.new(20, 0, 9),
	},
	FrostNight = {
		cover = 0.3,
		density = 0.3,
		color = Color3.fromRGB(220, 230, 245),
		wind = Vector3.new(4, 0, 2),
	},
	BunicaAngry = {
		cover = 0.8,
		density = 0.7,
		color = Color3.fromRGB(190, 120, 110),
		wind = Vector3.new(18, 0, 6),
	},
	Rainbow = {
		cover = 0.55,
		density = 0.45,
		color = Color3.fromRGB(255, 255, 255),
		wind = Vector3.new(6, 0, 3),
	},
}
local CALM =
	{ cover = 0.48, density = 0.42, color = Color3.fromRGB(255, 255, 255), wind = Vector3.new(7, 0, 3) }
local clouds: Clouds? = nil

local atmosphere: Atmosphere
local correction: ColorCorrectionEffect
local bloom: BloomEffect
local rays: SunRaysEffect
local phaseStart = 0
local lastPhase: string? = nil
local weatherBlend = 0

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

local function progress(phase: string): number
	local now = Workspace:GetServerTimeNow()
	local endsAt = GameState.get(GameState.Attributes.PhaseEndsAt)
	if type(endsAt) ~= "number" then
		return 0.5
	end
	local duration = if phase == "Night" then DayNight.nightSeconds else DayNight.daySeconds
	if phaseStart > 0 and endsAt > phaseStart then
		duration = endsAt - phaseStart -- faza a început cât eram aici: durata reală (Studio rulează accelerat)
	end
	if endsAt - now <= 0 then
		return 0.5 -- fază forțată sau oprită (timer 0): aspectul de mijloc al fazei, nu capătul ei
	end
	return 1 - math.clamp((endsAt - now) / duration, 0, 1)
end

local fogBlend = 0

local function apply(dt: number)
	local phase = GameState.get(GameState.Attributes.Phase) or "Day"
	if phase ~= lastPhase then
		-- prima observație (intrat la mijlocul fazei): începutul real nu-l știm, folosim durata din config
		phaseStart = if lastPhase == nil then 0 else Workspace:GetServerTimeNow()
		lastPhase = phase
	end
	local hour = SkyCycle.hourFor(phase, progress(phase))
	local look = SkyCycle.at(hour)
	local weather = GameState.get(GameState.Attributes.Weather)
	local tint = WEATHER_TINT[weather or ""]
	weatherBlend = math.clamp(weatherBlend + (if tint then dt else -dt) / 2.5, 0, 1)

	local brightness, saturation = look.brightness, look.saturation
	local colorTop, fog, tintColor = look.colorTop, look.fogColor, look.tint
	if tint and weatherBlend > 0 then
		local k = tint.amount * weatherBlend
		colorTop = colorTop:Lerp(tint.color, k)
		fog = fog:Lerp(tint.color, k)
		tintColor = tintColor:Lerp(tint.color, k * 0.6)
		saturation += tint.saturation * weatherBlend
		brightness *= 1 + (tint.brightness - 1) * weatherBlend
	end

	Lighting.ClockTime = hour
	Lighting.Brightness = brightness
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.ColorShift_Top = colorTop
	Lighting.ColorShift_Bottom = look.colorBottom
	-- ceața satului (întâmplarea „Ceața”): crește lin până la ținta de pe server
	local fogTarget = GameState.get(GameState.Attributes.Fog)
	fogBlend += math.clamp((if type(fogTarget) == "number" then fogTarget else 0) - fogBlend, -dt / 3, dt / 3)
	atmosphere.Color = fog:Lerp(Color3.fromRGB(196, 200, 206), fogBlend * 0.8)
	atmosphere.Decay = look.decay
	atmosphere.Haze = look.haze + fogBlend * 6
	atmosphere.Density = look.density + (0.72 - look.density) * fogBlend
	correction.TintColor = tintColor
	correction.Saturation = saturation
	correction.Contrast = look.contrast
	bloom.Intensity = look.bloom
	rays.Intensity = look.sunRays

	local sky = SKY_WEATHER[weather or ""] or CALM
	local blend = math.clamp(dt / 4, 0, 1) -- trecere lină (≈ 4 s)
	if clouds then
		clouds.Cover += (sky.cover - clouds.Cover) * blend
		clouds.Density += (sky.density - clouds.Density) * blend
		clouds.Color = clouds.Color:Lerp(sky.color, blend)
	end
	Workspace.GlobalWind = Workspace.GlobalWind:Lerp(sky.wind, blend)
end

function LightingDirector.start()
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	atmosphere = ensure("Atmosphere", "SatAtmosphere")
	atmosphere.Offset = 0.15
	atmosphere.Glare = 0.4
	correction = ensure("ColorCorrectionEffect", "SatColor")
	bloom = ensure("BloomEffect", "SatBloom")
	bloom.Size = 28
	bloom.Threshold = 1.6
	rays = ensure("SunRaysEffect", "SatRays")
	rays.Spread = 0.6
	local sky = ensure("Sky", "SatSky") :: Sky
	sky.StarCount = 3000
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 16
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local existing = terrain:FindFirstChildOfClass("Clouds")
		clouds = existing or Instance.new("Clouds")
		local made = clouds :: Clouds
		made.Cover = CALM.cover
		made.Density = CALM.density
		made.Parent = terrain
	end
	-- 10 actualizări pe secundă ajung pentru un soare care se mișcă lent
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			apply(accumulator)
			accumulator = 0
		end
	end)
	apply(0)
end

return LightingDirector
