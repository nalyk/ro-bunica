--!strict
-- Satul întreg, pe toate serverele (MessagingService, topicul „Sat”):
-- • momentele rare se anunță peste tot: Rețeta Secretă, ecloziunile mitice și secrete;
-- • comenzi de admin, publicate din afara jocului (`tools/cloud.py announce|live`, Open Cloud messaging):
--   un anunț pentru toată lumea sau pornirea unui eveniment live („Bunica se supără”) pe toate serverele.
-- Mesajele venite de la serverul propriu se ignoră (anunțul local a plecat deja).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LiveEventsConfig = require(Shared.Config.LiveEvents)
local Messenger = require(script.Parent.Messenger)
local LiveEventService = require(script.Parent.LiveEventService)
local Broadcast = require(script.Parent.Parent.Social.Broadcast)

local BroadcastService = {}

local ALLOWED_ANNOUNCE: { [string]: boolean } = {
	["announce.SecretRecipe"] = true,
	["announce.HatchEverywhere"] = true,
	["announce.Admin"] = true,
}

-- Un mesaj din topic (de la alt server sau de la admin); întoarce ce a făcut, pentru teste
function BroadcastService.receive(data: unknown): string
	if type(data) ~= "string" then
		return "ignored"
	end
	local ok, message = pcall(HttpService.JSONDecode, HttpService, data)
	if not ok or type(message) ~= "table" or message.j == game.JobId then
		return "ignored"
	end
	if type(message.k) == "string" and ALLOWED_ANNOUNCE[message.k] then
		local args = if type(message.a) == "table" then message.a else {}
		Messenger.announce(message.k, args)
		return "announced"
	end
	if message.live and type(message.live) == "string" then
		local event = LiveEventsConfig.byId[message.live]
		if event then
			local seconds = math.clamp(tonumber(message.s) or event.durationMinutes * 60, 60, 3600)
			LiveEventService.forceStart(event.id, seconds)
			return "live"
		end
	end
	return "ignored"
end

function BroadcastService.start()
	pcall(MessagingService.SubscribeAsync, MessagingService, Broadcast.TOPIC, function(message)
		BroadcastService.receive(message.Data)
	end)
end

return BroadcastService
