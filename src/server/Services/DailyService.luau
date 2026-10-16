--!strict
-- Recompensa zilnică pe serie (Domain/Daily): la intrare, după ecranul de încărcare, jucătorul primește
-- recompensa zilei și vede seria (fereastra de pe client). O zi UTC = o recompensă.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Daily = require(Shared.Domain.Daily)
local Analytics = require(script.Parent.Parent.Analytics)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)

type Owner = PlotService.Owner

local DailyService = {}

local SHOW_AFTER_SECONDS = 6 -- după ecranul de încărcare

-- Revendică pentru proprietar (folosit la intrare și de teste); nil dacă a luat-o azi
function DailyService.claim(owner: Owner, unixNow: number?): Daily.Claim?
	local claim = Daily.claim(owner.profile, Daily.dayOf(unixNow or os.time()))
	if not claim then
		return nil
	end
	EconomyService.addLei(owner, 0) -- clasamentul și starea
	StateService.markDirty(owner.player)
	Analytics.source(owner.player, owner.profile, claim.lei, "Daily", "day" .. claim.day)
	return claim
end

function DailyService.start()
	PlotService.onOwnerAdded(function(owner)
		if owner.kind ~= "Player" then
			return
		end
		task.delay(SHOW_AFTER_SECONDS, function()
			-- jucătorii noi văd întâi hoțul din primul minut; darul vine după (cel mult 3 minute de așteptat)
			local deadline = os.clock() + 180
			while
				not owner.profile.tutorialThiefDone
				and os.clock() < deadline
				and owner.plot.owner == owner
			do
				task.wait(1)
			end
			local player = owner.player
			if not player or not player.Parent or owner.plot.owner ~= owner then
				return
			end
			local claim = DailyService.claim(owner)
			if claim then
				Net.get("Daily"):FireClient(player, claim, Workspace:GetServerTimeNow())
			end
		end)
	end)
end

return DailyService
