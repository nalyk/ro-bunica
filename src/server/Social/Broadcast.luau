--!strict
-- Anunț pe toate serverele (MessagingService, topicul „Sat”): local imediat, apoi publicat pentru celelalte.
-- Fără dependențe de servicii, ca oricine să-l poată folosi (BroadcastService primește mesajele).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local Messenger = require(script.Parent.Parent.Services.Messenger)

local Broadcast = {}

Broadcast.TOPIC = "Sat"

function Broadcast.everywhere(key: string, args: { any }?)
	Messenger.announce(key, args)
	local ok, payload =
		pcall(HttpService.JSONEncode, HttpService, { k = key, a = args or {}, j = game.JobId })
	if ok then
		task.spawn(pcall, MessagingService.PublishAsync, MessagingService, Broadcast.TOPIC, payload)
	end
end

return Broadcast
