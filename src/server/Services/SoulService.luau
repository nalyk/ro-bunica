--!strict
-- Creaturile de suflet (Domain/Soul): jucătorul pune sau scoate inima de pe o creatură din beci sau de pe piedestal.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Soul = require(Shared.Domain.Soul)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Inventory = require(Shared.Domain.Inventory)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)

type Owner = PlotService.Owner

local SoulService = {}

local limiter = RateLimiter.new(6, 2)

-- Pune sau scoate inima. Întoarce dacă s-a schimbat.
function SoulService.set(owner: Owner, uid: string, on: boolean): boolean
	local ok, reason = Soul.canSet(owner.profile, uid, on)
	if not ok then
		if reason == "Max" then
			Messenger.notify(owner.player, "notify.SoulMax", { Soul.MAX })
		end
		return false
	end
	Soul.set(owner.profile, uid, on)
	local key = Inventory.findPedestal(owner.profile, uid)
	if key then
		CreatureService.renderKey(owner, key) -- inima de deasupra creaturii
	end
	StateService.markDirty(owner.player)
	return true
end

function SoulService.start()
	Net.get("SetSoul").OnServerEvent:Connect(function(player, uid, on)
		if
			typeof(uid) ~= "string"
			or typeof(on) ~= "boolean"
			or not limiter:allow(player.UserId, os.clock())
		then
			return
		end
		local owner = PlotService.getOwner(player)
		if owner then
			SoulService.set(owner, uid, on)
		end
	end)
end

return SoulService
