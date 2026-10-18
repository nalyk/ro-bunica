--!strict
-- Reglajul live (Roblox Configs + Experiments; Domain/Tuning): valorile de server se citesc la pornire și
-- la fiecare actualizare din Dashboard, se validează și se scriu în tabelele din Config; clientul primește
-- aceleași valori prin atributul „Tuning” (JSON) de pe ReplicatedStorage. Valorile pe jucător (papucul)
-- vin din GetConfigForPlayerAsync, deci pot intra în experimente A/B. Fără Configs (Studio, teste, cădere),
-- totul rămâne pe valorile din cod.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Domain.Tuning)

local TuningService = {}

local CONFIGS = {
	Defense = require(Shared.Config.Defense),
	Raid = require(Shared.Config.Raid),
	DayNight = require(Shared.Config.DayNight),
	Economy = require(Shared.Config.Economy),
}

local defaults: { [string]: number } = {} -- valorile din cod, pentru cheile scoase din Dashboard
local playerValues: { [Player]: { [string]: number }? } = {}
local snapshot: any = nil

local function readDefaults()
	for key, spec in Tuning.SPEC do
		local node: any = CONFIGS
		for _, part in string.split(spec.path, ".") do
			node = node and node[part]
		end
		if type(node) == "number" then
			defaults[key] = node
		end
	end
end

local function read(source: any, scope: string): { [string]: unknown }
	local values: { [string]: unknown } = {}
	for key, spec in Tuning.SPEC do
		if spec.scope == scope then
			local ok, value = pcall(source.GetValue, source, key)
			if ok and value ~= nil then
				values[key] = value
			end
		end
	end
	return values
end

-- Aplică valorile de server (peste cele din cod) și le trimite clienților
function TuningService.applyServer(values: { [string]: unknown }): { string }
	local ok, rejected = Tuning.validate(values)
	local merged: { [string]: number } = {}
	for key, spec in Tuning.SPEC do
		if spec.scope == "server" and defaults[key] then
			merged[key] = ok[key] or defaults[key]
		end
	end
	Tuning.apply(CONFIGS, merged)
	ReplicatedStorage:SetAttribute("Tuning", HttpService:JSONEncode(merged))
	if #rejected > 0 then
		warn("[Tuning] valori respinse: " .. table.concat(rejected, ", "))
	end
	return rejected
end

-- Valoarea pe jucător (experimente) sau cea din cod
function TuningService.forPlayer(player: Player?, key: string, default: number): number
	local values = player and playerValues[player]
	return if values then Tuning.playerValue(values, key, default) else default
end

-- Pentru teste: impune valorile unui jucător
function TuningService.setPlayer(player: Player, values: { [string]: number }?)
	playerValues[player] = values
end

local function loadPlayer(player: Player)
	local ConfigService = game:GetService("ConfigService" :: any)
	local ok, config = pcall((ConfigService :: any).GetConfigForPlayerAsync, ConfigService, player)
	if ok and config and player.Parent == Players then
		local valid = Tuning.validate(read(config, "player"))
		playerValues[player] = valid
	end
end

function TuningService.init()
	readDefaults()
end

function TuningService.start()
	local okService, ConfigService = pcall(game.GetService, game, "ConfigService")
	if okService and ConfigService then
		local ok, result = pcall((ConfigService :: any).GetConfigAsync, ConfigService)
		if ok and result then
			snapshot = result
			TuningService.applyServer(read(snapshot, "server"))
			pcall(function()
				snapshot.UpdateAvailable:Connect(function()
					pcall(snapshot.Refresh, snapshot)
					TuningService.applyServer(read(snapshot, "server"))
				end)
			end)
		end
		Players.PlayerAdded:Connect(function(player)
			task.spawn(loadPlayer, player)
		end)
		for _, player in Players:GetPlayers() do
			task.spawn(loadPlayer, player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		playerValues[player] = nil
	end)
end

return TuningService
