--!strict
-- Trimite fiecărui jucător starea lui (lei, semințe, creaturi, muniție…).
-- Serviciile apelează `markDirty`; trimiterea e grupată de câteva ori pe secundă.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Growth = require(Shared.Domain.Growth)
local Economy = require(Shared.Domain.Economy)
local PlotService = require(script.Parent.PlotService)

local FLUSH_INTERVAL = 0.2

local StateService = {}

type Provider = (Player, { [string]: any }) -> ()

local dirty: { [Player]: boolean } = {}
local providers: { Provider } = {}

local function snapshot(player: Player): { [string]: any }?
	local owner = PlotService.getOwner(player)
	if not owner then
		return nil
	end
	local profile = owner.profile
	local beds = {}
	for key, plant in profile.beds do
		beds[key] = {
			seedId = plant.seedId,
			size = plant.size,
			mutation = plant.mutation,
			progress = Growth.progress(plant),
		}
	end
	local state: { [string]: any } = {
		plotIndex = owner.plot.index,
		lei = profile.lei,
		seeds = profile.seeds,
		beds = beds,
		pedestals = profile.pedestals,
		cellar = profile.cellar,
		bedCount = profile.bedCount,
		pedestalCount = profile.pedestalCount,
		cellarCapacity = profile.cellarCapacity,
		shieldUntil = owner.shieldUntil,
		incomePerSecond = Economy.totalIncome(profile.pedestals, 1),
	}
	for _, provider in providers do
		provider(player, state)
	end
	return state
end

function StateService.markDirty(player: Player?)
	if player then
		dirty[player] = true
	end
end

-- Adaugă câmpuri în snapshot (de exemplu muniția papucului).
function StateService.addProvider(provider: Provider)
	table.insert(providers, provider)
end

function StateService.start()
	local remote = Net.get("State")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < FLUSH_INTERVAL then
			return
		end
		elapsed = 0
		for player in dirty do
			dirty[player] = nil
			if player.Parent == Players then
				local state = snapshot(player)
				if state then
					remote:FireClient(player, state)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		StateService.markDirty(player)
	end)
	PlotService.onOwnerAdded(function(owner)
		StateService.markDirty(owner.player)
	end)
end

return StateService
