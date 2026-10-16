--!strict
-- Ambianța satului, din atlasul audio: ziua vânt ușor, noaptea greieri, ploaie cât plouă (Rain, Hail).
-- Straturile se trec lin unul în altul la schimbarea fazei sau a vremii; muzica rămâne a dirijorului (Music).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioAtlas = require(Shared.Config.AudioAtlas)
local GameState = require(Shared.GameState)

local AmbienceController = {}

local FADE_SECONDS = 2.5
local LEVELS: { [string]: number } = { wind = 0.22, crickets = 0.3, rain = 0.4 }
local RAINY = { Rain = true, Hail = true }

local layers: { [string]: Sound } = {}

local function loop(name: string): Sound?
	local region = AudioAtlas.regions["sfx." .. name]
	if not region or AudioAtlas.assetId == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Ambience_" .. name
	sound.SoundId = "rbxassetid://" .. AudioAtlas.assetId
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
	sound.LoopRegion = NumberRange.new(region.start, region.start + region.length)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function target(name: string): number
	local phase = GameState.get(GameState.Attributes.Phase) or "Day"
	local weather = GameState.get(GameState.Attributes.Weather) or ""
	if name == "rain" then
		return if RAINY[weather] then LEVELS.rain else 0
	elseif name == "crickets" then
		return if phase == "Night" and not RAINY[weather] then LEVELS.crickets else 0
	else
		return if phase == "Day" then LEVELS.wind else LEVELS.wind * 0.4
	end
end

local function update()
	for name, sound in layers do
		TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = target(name) }):Play()
	end
end

-- Volumele țintă (pentru teste)
function AmbienceController.levels(): { [string]: number }
	local out = {}
	for name in layers do
		out[name] = target(name)
	end
	return out
end

function AmbienceController.start()
	for name in LEVELS do
		local sound = loop(name)
		if sound then
			layers[name] = sound
		end
	end
	GameState.changed(GameState.Attributes.Phase, update)
	GameState.changed(GameState.Attributes.Weather, update)
	update()
end

return AmbienceController
