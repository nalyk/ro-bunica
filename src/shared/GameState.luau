--!strict
-- Starea globală a serverului, replicată prin atribute pe un Folder din ReplicatedStorage.
-- Timpii sunt în `workspace:GetServerTimeNow()`, ca serverul și clienții să aibă același ceas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = {}

GameState.Attributes = table.freeze({
	Phase = "Phase", -- "Day" | "Night"
	PhaseEndsAt = "PhaseEndsAt",
	Weather = "Weather", -- id eveniment sau ""
	WeatherEndsAt = "WeatherEndsAt",
	ShopRestockAt = "ShopRestockAt",
	Season = "Season", -- "Primavara" | "Vara" | "Toamna" | "Iarna" (Domain/Seasons)
	Fog = "Fog", -- 0–1: ceața (întâmplarea „Ceața”), densitatea atmosferei pe client
})

local folder: Folder? = nil

function GameState.folder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "GameState"
		created.Parent = ReplicatedStorage
		folder = created
		return created
	end
	local found = ReplicatedStorage:WaitForChild("GameState") :: Folder
	folder = found
	return found
end

function GameState.get(attribute: string): any
	return GameState.folder():GetAttribute(attribute)
end

function GameState.set(attribute: string, value: any)
	GameState.folder():SetAttribute(attribute, value)
end

function GameState.changed(attribute: string, callback: (any) -> ()): RBXScriptConnection
	local target = GameState.folder()
	return target:GetAttributeChangedSignal(attribute):Connect(function()
		callback(target:GetAttribute(attribute))
	end)
end

return GameState
