--!strict
-- Codurile (Domain/Codes, Config/Codes): o folosire pe profil; răsplata în lei sau o sămânță.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Codes = require(Shared.Domain.Codes)
local CodeList = require(Shared.Config.Codes)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local CodeService = {}

local limiter = RateLimiter.new(5, 1 / 12) -- încercări rare: nu se ghicesc coduri

function CodeService.redeem(owner: Owner, input: string): (boolean, any)
	owner.profile.codes = owner.profile.codes or {}
	local ok, result = Codes.redeem(CodeList, owner.profile.codes, input, Workspace:GetServerTimeNow())
	if not ok then
		Messenger.notify(owner.player, "code." .. tostring(result))
		return false, result
	end
	if result.lei then
		EconomyService.addLei(owner, result.lei)
		Analytics.source(owner.player, owner.profile, result.lei, "Code")
		Messenger.notify(owner.player, "code.lei", { tostring(result.lei) })
	end
	if result.seed then
		owner.profile.seeds[result.seed] = (owner.profile.seeds[result.seed] or 0) + 1
		Messenger.notify(owner.player, "code.seed", { Messenger.key("creature." .. result.seed) })
	end
	StateService.markDirty(owner.player)
	return true, result
end

function CodeService.start()
	Net.get("Code").OnServerEvent:Connect(function(player, input)
		local owner = PlotService.getOwner(player)
		if
			owner
			and typeof(input) == "string"
			and #input <= 32
			and limiter:allow(player.UserId, os.clock())
		then
			CodeService.redeem(owner, input)
		end
	end)
end

return CodeService
