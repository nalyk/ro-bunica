--!strict
-- Politicile Roblox pe jucător (Domain/Policy), cerute o dată la intrare. Până sosește răspunsul (sau dacă
-- nu sosește deloc) jucătorul e tratat ca restricționat. Clientul le citește din atributele jucătorului:
-- PaidRandomRestricted (magazinul ascunde ce duce la rezultate aleatorii) și PaidTradingAllowed (schimburile
-- și bazarul). Boții și proprietarii fără jucător au voie la toate.
-- Nivelul de preț (MarketplaceService:GetUsersPriceLevelsAsync, Managed Pricing) se cere tot la intrare,
-- cum recomandă Roblox, și nu se păstrează după sesiune; fără el schimburile și bazarul sunt închise.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Policy = require(Shared.Domain.Policy)

local RegionPolicyService = {}

local TRIES = 3
local policies: { [number]: Policy.Policy? } = {} -- după UserId (boții de test au și ei unul)
local forced: { [number]: boolean? } = {} -- puse de teste: răspunsul PolicyService nu le mai schimbă
local levels: { [number]: number? } = {} -- nivelul de preț (1–1000), după UserId

local function apply(player: Player, policy: Policy.Policy)
	policies[player.UserId] = policy
	player:SetAttribute("PaidRandomRestricted", policy.randomRestricted)
	player:SetAttribute("PaidTradingAllowed", policy.tradingAllowed)
end

local function fetch(player: Player)
	if forced[player.UserId] then
		return
	end
	apply(player, Policy.fromInfo(false, nil))
	for attempt = 1, TRIES do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok then
			if player.Parent and not forced[player.UserId] then
				apply(player, Policy.fromInfo(true, info))
			end
			return
		end
		warn("[RegionPolicy] " .. tostring(info))
		task.wait(2 * attempt)
	end
end

local function fetchLevel(player: Player)
	for attempt = 1, TRIES do
		local ok, result =
			pcall(MarketplaceService.GetUsersPriceLevelsAsync, MarketplaceService, { player.UserId })
		if ok and type(result) == "table" then
			for _, info in result do
				if info.UserId == player.UserId and type(info.PriceLevel) == "number" and player.Parent then
					levels[player.UserId] = info.PriceLevel
					return
				end
			end
			return
		end
		task.wait(2 * attempt)
	end
end

-- Politica unui proprietar: a jucătorului lui; un bot fără politică pusă are voie la toate
function RegionPolicyService.get(owner: { userId: number, player: Player? }): Policy.Policy
	local policy = policies[owner.userId]
	if not policy then
		return if owner.player then Policy.fromInfo(false, nil) else Policy.OPEN
	end
	if policy.priceLevel == nil and levels[owner.userId] then
		return {
			randomRestricted = policy.randomRestricted,
			tradingAllowed = policy.tradingAllowed,
			priceLevel = levels[owner.userId],
		}
	end
	return policy
end

-- Schimb între doi proprietari (Domain/Policy.canTrade: niveluri de preț apropiate)
function RegionPolicyService.canTrade(
	a: { userId: number, player: Player? },
	b: { userId: number, player: Player? }
): boolean
	return Policy.canTrade(RegionPolicyService.get(a), RegionPolicyService.get(b))
end

-- Lei de la `from` la `to` (bazarul): nu dinspre o regiune mai ieftină spre una mai scumpă
function RegionPolicyService.canGive(
	from: { userId: number, player: Player? },
	to: { userId: number, player: Player? }
): boolean
	return Policy.canGive(RegionPolicyService.get(from), RegionPolicyService.get(to))
end

function RegionPolicyService.tradingAllowed(owner: { userId: number, player: Player? }): boolean
	return RegionPolicyService.get(owner).tradingAllowed
end

-- Pentru teste: politica unui proprietar pusă direct (nil o șterge)
function RegionPolicyService.set(userId: number, policy: Policy.Policy?)
	policies[userId] = policy
	forced[userId] = if policy then true else nil
	local player = Players:GetPlayerByUserId(userId)
	if player and policy then
		apply(player, policy)
	end
end

function RegionPolicyService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(fetch, player)
		task.spawn(fetchLevel, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
		task.spawn(fetchLevel, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		policies[player.UserId] = nil
		forced[player.UserId] = nil
		levels[player.UserId] = nil
	end)
end

return RegionPolicyService
