--!strict
-- Măsurătorile care nu țin de un singur serviciu: intrarea, prima noapte, apărările, cumpărările pe Robux.
-- (Sursele și cheltuielile de lei și restul pașilor din funnel se măsoară acolo unde se întâmplă.)

local Analytics = require(script.Parent.Parent.Analytics)
local Badges = require(script.Parent.Parent.Badges)
local PlotService = require(script.Parent.PlotService)
local DayNightService = require(script.Parent.DayNightService)
local RaidService = require(script.Parent.RaidService)
local MonetizationService = require(script.Parent.MonetizationService)

local MetricsService = {}

function MetricsService.start()
	game:GetService("Players").PlayerRemoving:Connect(Badges.forget)
	game:GetService("Players").PlayerRemoving:Connect(Analytics.forget)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" then
			Analytics.step(owner.player, owner.profile, "Joined")
		end
	end)
	DayNightService.onPhaseChanged(function(phase)
		if phase ~= "Night" then
			return
		end
		for _, owner in PlotService.owners() do
			if owner.kind == "Player" then
				Analytics.step(owner.player, owner.profile, "FirstNight")
			end
		end
	end)
	RaidService.onActorHit(function(_victim, source)
		local thrower = source.thrower
		local owner = thrower and PlotService.getOwnerOfActor(thrower)
		if thrower and owner then
			Analytics.step(thrower.player, owner.profile, "FirstDefend")
			Analytics.event(thrower.player, "Defend")
			Badges.award(thrower.player, "defend")
		end
	end)
	MonetizationService.onPurchase(function(player, key, robux)
		Analytics.event(player, "Robux_" .. key, robux)
	end)
end

return MetricsService
