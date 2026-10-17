--!strict
-- Răzbunarea (Domain/Revenge): după un furt, victima își vede hoțul și creatura până în zori. Dacă și-o fură
-- înapoi în noaptea asta, primește jumătate din prețul ei în plus.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Revenge = require(Shared.Domain.Revenge)
local Economy = require(Shared.Domain.Economy)
local PlotService = require(script.Parent.PlotService)
local RaidService = require(script.Parent.RaidService)
local DayNightService = require(script.Parent.DayNightService)
local EconomyService = require(script.Parent.EconomyService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local RevengeService = {}

local marks = Revenge.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Pentru teste: marcajele active.
function RevengeService.marks(): Revenge.Marks
	return marks
end

local function onSteal(thief: Owner, victim: Owner, record: any)
	local t = now()
	if Revenge.claim(marks, thief.userId, record.uid, t) then
		local bonus = Revenge.bonus(Economy.sellPrice(record))
		EconomyService.addLei(thief, bonus)
		Analytics.source(thief.player, thief.profile, bonus, "Revenge")
		Messenger.notify(
			thief.player,
			"notify.RevengeDone",
			{ Messenger.key("creature." .. record.id), Economy.formatShort(bonus) }
		)
		if thief.player then
			Net.get("Revenge"):FireClient(thief.player, nil)
		end
		return
	end
	local untilTime = GameState.get(GameState.Attributes.PhaseEndsAt) or (t + 180)
	Revenge.mark(marks, victim.userId, thief.userId, record.uid, untilTime)
	if victim.player then
		Messenger.notify(victim.player, "notify.RevengeStart", { thief.name })
		Net.get("Revenge")
			:FireClient(victim.player, { thief = thief.userId, name = thief.name, uid = record.uid })
	end
end

function RevengeService.start()
	RaidService.onSteal(onSteal)
	DayNightService.onPhaseChanged(function(phase)
		if phase == "Day" then
			Revenge.clear(marks)
			Net.get("Revenge"):FireAllClients(nil)
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		if owner.player then
			Net.get("Revenge"):FireClient(owner.player, nil)
		end
	end)
end

return RevengeService
