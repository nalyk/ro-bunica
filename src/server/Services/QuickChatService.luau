--!strict
-- Mesajele rapide (Config/QuickChat): jucătorul alege unul din 12; deasupra capului apare o bulă (atributul
-- „Quick” pe personaj = "id:număr", tradusă pe client). Fără text liber, deci sigur pentru orice vârstă.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local QuickChat = require(Shared.Config.QuickChat)

local QuickChatService = {}

local lastAt: { [Player]: number } = {}
local counter = 0

function QuickChatService.say(player: Player, id: string): boolean
	local known = false
	for _, message in QuickChat.list do
		known = known or message.id == id
	end
	local character = player.Character
	if not known or not character then
		return false
	end
	local now = os.clock()
	if now - (lastAt[player] or -math.huge) < QuickChat.cooldown then
		return false
	end
	lastAt[player] = now
	counter += 1
	character:SetAttribute("Quick", id .. ":" .. counter)
	return true
end

function QuickChatService.start()
	Net.get("QuickChat").OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" then
			QuickChatService.say(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
	end)
end

return QuickChatService
