--!strict
-- Ciclul zi/noapte. Publică faza în GameState; clienții fac tranziția vizuală.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayNight = require(Shared.Domain.DayNight)
local GameState = require(Shared.GameState)
local Messenger = require(script.Parent.Messenger)

-- În Studio ciclul merge de 4 ori mai repede, ca furturile să poată fi testate repede
local SPEED = if RunService:IsStudio() then 4 else 1

local DayNightService = {}

local currentPhase: "Day" | "Night" = "Day"
local callbacks: { (string) -> () } = {}

function DayNightService.phase(): "Day" | "Night"
	return currentPhase
end

function DayNightService.onPhaseChanged(callback: (string) -> ())
	table.insert(callbacks, callback)
end

function DayNightService.start()
	local startedAt = Workspace:GetServerTimeNow()
	local first = true
	while true do
		local now = Workspace:GetServerTimeNow()
		local info = DayNight.at((now - startedAt) * SPEED)
		if first or info.phase ~= currentPhase then
			currentPhase = info.phase
			GameState.set(GameState.Attributes.Phase, info.phase)
			GameState.set(GameState.Attributes.PhaseEndsAt, now + info.secondsLeft / SPEED)
			if not first then
				Messenger.announce(if info.phase == "Night" then "announce.Night" else "announce.Day")
				for _, callback in callbacks do
					task.spawn(callback, info.phase)
				end
			end
			first = false
		end
		task.wait(0.5)
	end
end

return DayNightService
