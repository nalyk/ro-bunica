--!strict
-- Abonamentul „Prietenii Bunicii” (Roblox Subscriptions, Domain/Subscription): starea se verifică la
-- intrare și la fiecare schimbare (UserSubscriptionStatusChanged) și ajunge în atributul „Subscriber” al
-- jucătorului; ținuta de aur și titlul depind de el. Cumpărarea o pornește clientul
-- (MarketplaceService:PromptSubscriptionPurchase). Fără id în Config/Monetization, nimic.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local PlotService = require(script.Parent.PlotService)
local OutfitService = require(script.Parent.OutfitService)
local StateService = require(script.Parent.StateService)

local SubscriptionService = {}

local function check(player: Player)
	local id = Monetization.subscription
	if id == "" or player.Parent ~= Players then
		return
	end
	local ok, status =
		pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player, id)
	local subscribed = ok and type(status) == "table" and status.IsSubscribed == true
	if player:GetAttribute("Subscriber") ~= subscribed then
		player:SetAttribute("Subscriber", subscribed)
		local owner = PlotService.getOwner(player)
		if owner then
			OutfitService.apply(owner)
			StateService.markDirty(player)
		end
	end
end

-- Pentru teste: impune starea
function SubscriptionService.set(player: Player, subscribed: boolean)
	player:SetAttribute("Subscriber", subscribed)
end

function SubscriptionService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(check, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	pcall(function()
		(Players :: any).UserSubscriptionStatusChanged:Connect(
			function(player: Player, subscriptionId: string)
				if subscriptionId == Monetization.subscription then
					check(player)
				end
			end
		)
	end)
end

return SubscriptionService
