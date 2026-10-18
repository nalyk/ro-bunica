--!strict
-- Valorile reglate live pe server (TuningService, Roblox Configs) ajung și aici: atributul „Tuning” de pe
-- ReplicatedStorage (JSON) se scrie în aceleași tabele din Config, ca predicțiile clientului (ziua, papucul,
-- Bunica) să fie la fel cu ale serverului.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Domain.Tuning)

local CONFIGS = {
	Defense = require(Shared.Config.Defense),
	Raid = require(Shared.Config.Raid),
	DayNight = require(Shared.Config.DayNight),
	Economy = require(Shared.Config.Economy),
}

local TuningClient = {}

local function apply()
	local text = ReplicatedStorage:GetAttribute("Tuning")
	if type(text) ~= "string" then
		return
	end
	local ok, values = pcall(HttpService.JSONDecode, HttpService, text)
	if ok and type(values) == "table" then
		local valid = Tuning.validate(values)
		Tuning.apply(CONFIGS, valid)
	end
end

function TuningClient.start()
	apply()
	ReplicatedStorage:GetAttributeChangedSignal("Tuning"):Connect(apply)
end

return TuningClient
